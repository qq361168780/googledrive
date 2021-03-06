# this is fully copied from googlesheets with all `gs` replaced with `gd` and
# `googlesheets` with `googledrive`

#' Produce Google token
#'
#' If token is not already available, call [drive_auth()] to either load
#' from cache or initiate OAuth2.0 flow. Return the token -- not "bare" but,
#' rather, prepared for inclusion in downstream requests. Use
#' `access_token()` to reveal the actual access token, suitable for use
#' with `curl`.
#' @template verbose
#'
#' @return a `request` object (an S3 class provided by
#'   [`httr`][httr:httr-package])
#'
#' @keywords internal
drive_token <- function(verbose = FALSE) {
  if (!token_available(verbose = verbose)) drive_auth(verbose = verbose)
  httr::config(token = .state$token)
}

#' @rdname drive_token
include_token_if <- function(cond) if (cond) drive_token() else NULL
#' @rdname drive_token
omit_token_if <- function(cond) if (cond) NULL else drive_token()

#' Authorize googledrive.
#'
#' Authorize googledrive to view and manage your files. You will be directed to
#' a web browser, asked to sign in to your Google account, and to grant
#' googledrive permission to operate on your behalf with Google Sheets and
#' Google Drive. By default, these user credentials are cached in a file named
#' `.httr-oauth` in the current working directory, from where they can be
#' automatically refreshed, as necessary.
#'
#' Most users, most of the time, do not need to call this function explicitly --
#' it will be triggered by the first action that requires authorization. Even
#' when called, the default arguments will often suffice. However, when
#' necessary, this function allows the user to
#'   * force the creation of a new token
#'   * retrieve current token as an object, for possible storage to an `.rds`
#'     file
#'   * read the token from an object or from an `.rds` file
#'   * provide your own app key and secret -- this requires setting up a new
#'     project in
#'     [Google Developers Console](https://console.developers.google.com)
#'   * prevent caching of credentials in `.httr-oauth`
#'
#' In a direct call to `drive_auth()`, the user can provide the token, app key
#' and secret explicitly and can dictate whether interactively-obtained
#' credentials will be cached in `.httr_oauth`. If unspecified, these arguments
#' are controlled via options, which, if undefined at the time googledrive is
#' loaded, are defined like so:
#'   * __key__ Set to option `googledrive.client_id`, which defaults to a
#'     client ID that ships with the package
#'   * __secret__ Set to option `googledrive.client_secret`, which defaults to
#'     a client secret that ships with the package
#'   * __cache__ Set to option `googledrive.httr_oauth_cache`, which defaults
#'     to `TRUE`
#'
#' To override these defaults in persistent way, predefine one or more of
#' them with lines like this in a `.Rprofile` file:
#' ```
#' options(googledrive.client_id = "FOO",
#'         googledrive.client_secret = "BAR",
#'         googledrive.httr_oauth_cache = FALSE)
#' ```
#' See [base::Startup] for possible locations for this file and the
#' implications thereof.
#'
#' More detail is available from
#' [Using OAuth 2.0 for Installed Applications](https://developers.google.com/identity/protocols/OAuth2InstalledApp)
#'
#' @param token optional; an actual token object or the path to a valid token
#'   stored as an `.rds` file

#' @param new_user logical, defaults to `FALSE`. Set to `TRUE` if you want to
#'   wipe the slate clean and re-authenticate with the same or different Google
#'   account. This disables the `.httr-oauth` file in current working
#'   directory.
#' @param key,secret the "Client ID" and "Client secret" for the application;
#'   defaults to the ID and secret built into the googledrive package
#' @param cache logical indicating if googledrive should cache credentials in
#'   the default cache file `.httr-oauth`
#' @template verbose
#' @family auth functions
#' @export
#'
#' @examples
#' \dontrun{
#' ## load/refresh existing credentials, if available
#' ## otherwise, go to browser for authentication and authorization
#' drive_auth()
#'
#' ## force a new token to be obtained
#' drive_auth(new_user = TRUE)
#'
#' ## store token in an object and then to file
#' ttt <- drive_auth()
#' saveRDS(ttt, "ttt.rds")
#'
#' ## load a pre-existing token
#' drive_auth(token = ttt)       # from an object
#' drive_auth(token = "ttt.rds") # from .rds file
#' }
drive_auth <- function(token = NULL,
                       new_user = FALSE,
                       key = getOption("googledrive.client_id"),
                       secret = getOption("googledrive.client_secret"),
                       cache = getOption("googledrive.httr_oauth_cache"),
                       verbose = TRUE) {

  if (new_user) {
    drive_deauth(clear_cache = TRUE, verbose = verbose)
  }

  if (is.null(token)) {

    scope_list <- "https://www.googleapis.com/auth/drive"
    googledrive_app <- httr::oauth_app("google", key = key, secret = secret)
    drive_token <-
      httr::oauth2.0_token(httr::oauth_endpoints("google"), googledrive_app,
                           scope = scope_list, cache = cache)
    stopifnot(is_legit_token(drive_token, verbose = TRUE))
    .state$token <- drive_token

  } else if (inherits(token, "Token2.0")) {

    stopifnot(is_legit_token(token, verbose = TRUE))
    .state$token <- token

  } else if (inherits(token, "character")) {

    drive_token <- try(suppressWarnings(readRDS(token)), silent = TRUE)
    if (inherits(drive_token, "try-error")) {
      stop(
        glue("Cannot read token from alleged .rds file:\n{token}"),
        call. = FALSE
      )
    } else if (!is_legit_token(drive_token, verbose = TRUE)) {
      stop(
        glue("File does not contain a proper token:\n{token}"),
        call. = FALSE
      )
    }
    .state$token <- drive_token
  } else {
    stop(
      glue(
        "Input provided via 'token' is neither a token,\n",
        "nor a path to an .rds file containing a token."
      ),
      call. = FALSE
    )
  }

  .state$user <- guser()

  invisible(.state$token)

}


#' Check token availability
#'
#' Check if a token is available in googledrive internal `.state` environment.
#'
#' @return logical
#'
#' @keywords internal
token_available <- function(verbose = TRUE) {

  if (is.null(.state$token)) {
    if (verbose) {
      if (file.exists(".httr-oauth")) {
        message("A .httr-oauth file exists in current working ",
                "directory.\nWhen/if needed, the credentials cached in ",
                ".httr-oauth will be used for this session.\nOr run drive_auth() ",
                "for explicit authentication and authorization.")
      } else {
        message("No .httr-oauth file exists in current working directory.\n",
                "When/if needed, 'googledrive' will initiate authentication ",
                "and authorization.\nOr run drive_auth() to trigger this ",
                "explicitly.")
      }
    }
    return(FALSE)
  }

  TRUE

}

#' Suspend authorization.
#'
#' Suspend googledrive's authorization to place requests to the Drive API on
#' behalf of the authenticated user.
#'
#' @param clear_cache logical indicating whether to disable the
#'   `.httr-oauth` file in working directory, if such exists, by renaming
#'   to `.httr-oauth-SUSPENDED`
#' @template verbose
#'
#' @export
#' @family auth functions
#' @examples
#' \dontrun{
#' drive_deauth()
#' }
drive_deauth <- function(clear_cache = TRUE, verbose = TRUE) {

  if (clear_cache && file.exists(".httr-oauth")) {
    if (verbose) {
      message("Disabling .httr-oauth by renaming to .httr-oauth-SUSPENDED")
    }
    file.rename(".httr-oauth", ".httr-oauth-SUSPENDED")
  }

  if (token_available(verbose = FALSE)) {
    if (verbose) {
      message("Removing google token stashed internally in 'googledrive'.")
    }
    rm("token", envir = .state)
  } else {
    message("No token currently in force.")
  }

  invisible(NULL)

}

#' Check that token appears to be legitimate
#'
#' @keywords internal
is_legit_token <- function(x, verbose = FALSE) {

  if (!inherits(x, "Token2.0")) {
    if (verbose) message("Not a Token2.0 object.")
    return(FALSE)
  }

  if ("invalid_client" %in% unlist(x$credentials)) {
    # shouldn't happen if id and secret are good
    if (verbose) {
      message("Authorization error. Please check client_id and client_secret.")
    }
    return(FALSE)
  }

  if ("invalid_request" %in% unlist(x$credentials)) {
    # in past, this could happen if user clicks "Cancel" or "Deny" instead of
    # "Accept" when OAuth2 flow kicks to browser ... but httr now catches this
    if (verbose) message("Authorization error. No access token obtained.")
    return(FALSE)
  }

  TRUE

}

## useful when debugging
access_token <- function() {
  if (!token_available(verbose = TRUE)) return(NULL)
  .state$token$credentials$access_token
}
