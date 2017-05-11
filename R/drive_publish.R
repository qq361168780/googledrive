#' Publish Google Drive file
#'
#' @param file `gfile` object representing the file you would like to
#'   publish
#' @param publish logical, indicating whether you'd like to publish the most
#'   recent revision of the file (default `TRUE`)
#' @param ... name-value pairs to add to the API request body, for example
#'   `publishAuto = FALSE` will ensure that each subsequent revision will not be
#'   automatically published (default here is `publishAuto = TRUE`)
#' @param verbose logical, indicating whether to print informative messages
#'   (default `TRUE`)
#'
#' @return `gfile` object, a list with published information as a `tibble`
#'   added under the list element `publish`
#' @export
drive_publish <- function(file = NULL, publish = TRUE, ..., verbose = TRUE){

  file_update <- drive_check_publish(file = file, verbose = FALSE)

  request <- build_drive_publish(file = file_update, publish = publish, ...)
  response <- make_request(request, encode = "json")
  proc_res <- process_drive_publish(response = response, file = file_update, verbose = verbose)

  ##for some reason we have to make the request 2x?
  response <- make_request(request, encode = "json")
  proc_res <- process_drive_publish(response = response, file = file_update, verbose = FALSE)

  file_update <- drive_file(file$id)
  drive_check_publish(file = file_update, verbose = FALSE)
}

build_drive_publish <- function(file = NULL, publish = TRUE, ..., token = drive_token()){

  x <- list(...)
  if ("publishAuto" %in% names(x)){
    params = list(...,
                  published = publish)
  } else {
    params = list(published = publish,
                  publishAuto = TRUE,
                  ...)
  }

  id <- file$id

  rev_id <- file$publish$revision
  url <- file.path(.state$drive_base_url_files_v3, id,"revisions", rev_id)
  build_request(endpoint = url,
                params = params,
                token = token,
                method = "PATCH")
}

process_drive_publish <- function(response = NULL, file = NULL, verbose = TRUE){

  proc_res <- process_request(response)

  if (verbose){
    if(response$status_code == 200L){
      message(sprintf("You have changed the publication status of '%s'.", file$name))
    } else
      message(sprintf("Uh oh, something went wrong. The publication status of '%s' was not changed", file$name))
  }
}

#' Check if Google Drive file is published
#'
#' @param file `gfile` object representing the file you would like to check the published status of
#' @param verbose logical, indicating whether to print informative messages (default `TRUE`)
#'
#' @return `gfile` object, a list with published information as a `tibble` under the list element `publish`
#' @export
drive_check_publish <- function (file = NULL, verbose = TRUE){

  request <- build_drive_check_publish1(file = file)
  response <- make_request(request)
  proc_res <- process_request(response)

  request <- build_drive_check_publish2(file = file, proc_res = proc_res)
  response <- make_request(request)
  process_drive_check_publish(response = response, file = file, verbose = verbose)
}

build_drive_check_publish1 <- function(file = NULL, token = drive_token()){
  if(!inherits(file, "gfile")){
    spf("Input must be a `gfile`. See `drive_file()`")
  }

  id <- file$id

  url <- file.path(.state$drive_base_url_files_v3, id,"revisions")

  build_request(endpoint = url,
                token = token)
}

build_drive_check_publish2 <- function(file = NULL, proc_res = NULL, token = drive_token()){
  last_rev <- length(proc_res$revisions)
  rev_id <- proc_res$revisions[[last_rev]]$id

  fields <- paste(c("id","published","publishAuto","lastModifyingUser"), collapse = ",")

  id <- file$id
  url <- file.path(.state$drive_base_url_files_v3, id,"revisions",rev_id)
  req <- build_request(endpoint = url,
                       token = token,
                       params = list(fields = fields))
}

process_drive_check_publish <- function(response = NULL, file = NULL, verbose = TRUE){
  proc_res <- process_request(response)

  file$publish <- tibble::tibble(
    check_time = Sys.time(),
    revision = proc_res$id,
    published = proc_res$published,
    auto_publish = ifelse(!is.null(proc_res$publishAuto), proc_res$publishAuto, FALSE)
  )

  if (verbose){
    if (proc_res$published) {
      message(sprintf("The latest revision of Google Drive file '%s' is published.", file$name))
    } else
      message(sprintf("The latest revision of the Google Drive file '%s' is not published.", file$name))
  }

  invisible(file)
}