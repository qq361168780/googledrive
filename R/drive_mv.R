#' Move a Drive file.
#'
#' Move a Drive file to a different folder, give it a different name, or both.
#'
#' @template file
#' @template path
#' @param name Character, new file name if not specified as part of `path`. Any
#'   name obtained from `path` overrides this argument. Defaults to current
#'   name.
#' @template verbose
#'
#' @template dribble-return
#' @export
#' @examples
#' \dontrun{
#' ## create a file to move
#' file <- drive_upload(system.file("DESCRIPTION"), "DESC")
#'
#' ## rename it, but leave in current folder (root folder, in this case)
#' file <- drive_mv(file, "DESC-renamed")
#'
#' ## create a folder to move the file into
#' folder <- drive_mkdir("new-folder")
#'
#' ## move the file and rename it again,
#' ## specify destination as a dribble
#' file <- drive_mv(file, path = folder, name = "DESC-re-renamed")
#'
#' ## verify renamed file is now in the folder
#' drive_ls(folder)
#'
#' ## move the file back to root folder
#' file <- drive_mv(file, "~/")
#'
#' ## move it again
#' ## specify destination as path with trailing slash
#' ## to ensure we get a move vs. renaming it to "new-folder"
#' file <- drive_mv(file, "new-folder/")
#' }
drive_mv <- function(file = NULL, path = NULL, name = NULL, verbose = TRUE) {
  file <- as_dribble(file)
  file <- confirm_single_file(file)
  if (!is_mine(file)) {
    stop(
      glue("Can't move this file because you don't own it:\n{file$name}"),
      call. = FALSE
    )
  }

  if (!is.null(name)) {
    stopifnot(is_path(name), length(name) == 1)
  }

  if (is_path(path)) {
    if (is.null(name) && drive_path_exists(append_slash(path))) {
      path <- append_slash(path)
    }
    path_parts <- partition_path(path, maybe_name = is.null(name))
    path <- path_parts$parent
    name <- name %||% path_parts$name
  }

  name <- name %||% file$name

  params <- list(
    fileId = file$id,
    name = name,
    fields = "*"
  )

  ## if moving the file, modify the parent
  if (!is.null(path)) {
    path <- as_dribble(path)
    confirm_single_file(path)
    if (!is_folder(path)) {
      stop(
        glue(
          "Requested parent folder does not exist:\n{path$name}"
        ),
        call. = FALSE
      )
    }
    current_parents <- file$files_resource[[1]][["parents"]][[1]]
    if (!path$id %in% current_parents) {
      params[["addParents"]] <- path$id
      params[["removeParents"]] <- current_parents
    }
  }

  request <- generate_request(
    endpoint = "drive.files.update",
    params = params
  )
  res <- make_request(request, encode = "json")
  proc_res <- process_response(res)
  out <- as_dribble(list(proc_res))

  if (verbose) {
    renamed <- !identical(params$name, file$name)
    moved <- !is.null(params[["addParents"]])
    action <- glue("{if (renamed) 'renamed' else ''}",
                   "{if (renamed && moved) ' and ' else ''}",
                   "{if (moved) 'moved' else ''}")
    ## not entirely sure why this placement of `\n` helps glue do the right
    ## thing and yet ... it does
    new_path <- paste0(append_slash(path$name), out$name)
    message(glue("\nFile {action}:\n  * {file$name} -> {new_path}"))
  }
  invisible(out)
}

#' @rdname drive_mv
#' @export
drive_move <- drive_mv
