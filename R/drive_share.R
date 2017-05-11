#' Update Google Drive file share permissions
#'
#' @param file `gfile` object representing the file you would like to
#'   delete
#' @param role The role granted by this permission. Valid values are:
#' * organizer
#' * owner
#' * writer
#' * commenter
#' * reader
#' @param type The type of the grantee. Valid values are:
#' * user
#' * group
#' * domain
#' * anyone
#' @param email The email address of the user or group to which this permission
#'   refers.
#' @param message A custom message to include in the notification email.
#' @param ... name-value pairs to add to the API request body
#' @param verbose logical, indicating whether to print informative messages
#'   (default `TRUE`)
#'
#' @return `gfile` object updated with new sharing information
#' @export
drive_share <- function(file = NULL, role = NULL, type = NULL, email = NULL, message = NULL, ..., verbose = TRUE){

  request <- build_drive_share(file = file, role = role, type = type, email = email, message = message, ...)
  response <- make_request(request, encode = 'json')
  process_drive_share(response = response, file = file, verbose = verbose)

  file <- drive_file(file$id)
  invisible(file)
}

build_drive_share <- function(file = NULL, role = NULL, type = NULL, email = NULL, message = NULL, ..., token = drive_token()){

  if (!inherits(file, "gfile")) {
    spf("Input must be a `gfile`. See `drive_file()`")
  }

  ok_roles <- c("organizer", "owner", "writer", "commenter", "reader")
  ok_types <- c("user","group","domain","anyone")

  if (!is.null(role)) if (!(role %in% ok_roles)){
    spf("Role must be one of the following: %s.",paste(ok_roles, collapse = ", "))
  }

  if (!is.null(type)) if (!(type %in% ok_types)){
    spf("Role must be one of the following: %s.",paste(ok_types, collapse = ", "))
  }

  id <- file$id

  body <- list(role = role,
               type = type,
               emailAddress = email,...)

  url <- file.path(.state$drive_base_url_files_v3, id, "permissions")

  if (!is.null(message)) {
    message <- gsub(" ", "%20", message)
    url <- paste0(url,"?emailMessage=", message)
  }

  build_request(endpoint = url,
                token = token,
                params = body,
                method = "POST")
}

process_drive_share <- function(response = NULL, file = NULL, verbose = TRUE){

  process_request(response, content = FALSE)

  if (verbose==TRUE){
    if (response$status_code == 200L){
      message(sprintf("The permissions for file '%s' have been updated", file$name))
    } else {
      message(sprintf("Zoinks! Something went wrong, '%s' permissions were not updated.", file$name))
    }
  }
}