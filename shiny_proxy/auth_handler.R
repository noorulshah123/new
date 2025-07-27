# auth_handler.R - Authentication handler for pre-initialized ShinyProxy containers
# This file should be sourced at the beginning of your Shiny app

library(shiny)
library(httr)
library(jsonlite)

#' Get authentication information from headers or environment
#' @return list with user information
get_auth_info <- function() {
  # Check if we're in a pre-initialized container
  is_preinit <- Sys.getenv("SP_CONTAINER_PRE_INIT", "false") == "true"
  auth_type <- Sys.getenv("SP_AUTH_TYPE", "env")
  
  if (is_preinit && auth_type == "header") {
    # Get authentication from headers
    user_info <- get_auth_from_headers()
  } else {
    # Get authentication from environment variables (traditional method)
    user_info <- get_auth_from_env()
  }
  
  # Validate and return user info
  validate_user_info(user_info)
}

#' Extract authentication information from HTTP headers
#' @return list with user information
get_auth_from_headers <- function() {
  # In Shiny, headers are available through session$request$HTTP_*
  session <- getDefaultReactiveDomain()
  
  if (is.null(session)) {
    # Not in a reactive context, try to get from plumber or direct HTTP
    headers <- get_http_headers()
  } else {
    headers <- get_shiny_headers(session)
  }
  
  list(
    user_id = headers$user_id,
    user_groups = parse_groups(headers$user_groups),
    user_attributes = parse_json_safe(headers$user_attributes),
    access_token = headers$access_token,
    id_token = headers$id_token,
    session_id = headers$session_id,
    team_name = headers$team_name,
    app_id = headers$app_id
  )
}

#' Get HTTP headers in Shiny context
#' @param session Shiny session object
#' @return list of headers
get_shiny_headers <- function(session) {
  req <- session$request
  
  list(
    user_id = req$HTTP_X_SP_USERID,
    user_groups = req$HTTP_X_SP_USERGROUPS,
    user_attributes = req$HTTP_X_SP_USERATTRIBUTES,
    access_token = req$HTTP_X_SP_ACCESSTOKEN,
    id_token = req$HTTP_X_SP_IDTOKEN,
    session_id = req$HTTP_X_SP_SESSIONID,
    team_name = req$HTTP_X_SP_TEAMNAME,
    app_id = req$HTTP_X_SP_APPID
  )
}

#' Get HTTP headers outside Shiny context
#' @return list of headers
get_http_headers <- function() {
  # This function would need to be implemented based on your specific setup
  # For example, if using plumber or other R web frameworks
  list(
    user_id = Sys.getenv("HTTP_X_SP_USERID"),
    user_groups = Sys.getenv("HTTP_X_SP_USERGROUPS"),
    user_attributes = Sys.getenv("HTTP_X_SP_USERATTRIBUTES"),
    access_token = Sys.getenv("HTTP_X_SP_ACCESSTOKEN"),
    id_token = Sys.getenv("HTTP_X_SP_IDTOKEN"),
    session_id = Sys.getenv("HTTP_X_SP_SESSIONID"),
    team_name = Sys.getenv("HTTP_X_SP_TEAMNAME"),
    app_id = Sys.getenv("HTTP_X_SP_APPID")
  )
}

#' Get authentication from environment variables
#' @return list with user information
get_auth_from_env <- function() {
  list(
    user_id = Sys.getenv("SHINYPROXY_USERNAME"),
    user_groups = parse_groups(Sys.getenv("SHINYPROXY_USERGROUPS")),
    user_attributes = list(),  # Not available in env vars
    access_token = Sys.getenv("SHINYPROXY_OIDC_ACCESS_TOKEN"),
    id_token = Sys.getenv("SHINYPROXY_OIDC_ID_TOKEN"),
    session_id = Sys.getenv("SHINYPROXY_SESSION_ID"),
    team_name = Sys.getenv("SP_TEAM_NAME"),
    app_id = Sys.getenv("SHINYPROXY_APP_ID")
  )
}

#' Parse comma-separated groups string
#' @param groups_str Comma-separated groups string
#' @return character vector of groups
parse_groups <- function(groups_str) {
  if (is.null(groups_str) || groups_str == "") {
    return(character(0))
  }
  trimws(strsplit(groups_str, ",")[[1]])
}

#' Safely parse JSON string
#' @param json_str JSON string
#' @return parsed object or empty list
parse_json_safe <- function(json_str) {
  if (is.null(json_str) || json_str == "") {
    return(list())
  }
  
  tryCatch({
    fromJSON(json_str, simplifyVector = FALSE)
  }, error = function(e) {
    warning(paste("Failed to parse JSON:", e$message))
    list()
  })
}

#' Validate user information
#' @param user_info User information list
#' @return validated user information
validate_user_info <- function(user_info) {
  if (is.null(user_info$user_id) || user_info$user_id == "") {
    stop("No user authentication information found")
  }
  
  # Set defaults for missing fields
  if (is.null(user_info$user_groups)) {
    user_info$user_groups <- character(0)
  }
  
  if (is.null(user_info$user_attributes)) {
    user_info$user_attributes <- list()
  }
  
  user_info
}

#' Check if user has specific group membership
#' @param user_info User information from get_auth_info()
#' @param required_groups Character vector of required groups (ANY match)
#' @return logical
has_group <- function(user_info, required_groups) {
  any(user_info$user_groups %in% required_groups)
}

#' Check if user has all specified groups
#' @param user_info User information from get_auth_info()
#' @param required_groups Character vector of required groups (ALL match)
#' @return logical
has_all_groups <- function(user_info, required_groups) {
  all(required_groups %in% user_info$user_groups)
}

#' Create a user session cache
#' @param user_info User information from get_auth_info()
#' @return environment for caching user-specific data
create_user_cache <- function(user_info) {
  cache <- new.env(parent = emptyenv())
  cache$user_id <- user_info$user_id
  cache$team_name <- user_info$team_name
  cache$created_at <- Sys.time()
  
  # Add Redis namespace if available
  redis_namespace <- Sys.getenv("REDIS_NAMESPACE")
  if (redis_namespace != "") {
    cache$redis_key_prefix <- paste0(redis_namespace, ":", user_info$user_id)
  }
  
  cache
}

#' Example usage in a Shiny app
#' This shows how to integrate authentication in your app
if (FALSE) {  # Example code, not executed
  ui <- fluidPage(
    titlePanel("Authenticated Shiny App"),
    sidebarLayout(
      sidebarPanel(
        h4("User Information"),
        verbatimTextOutput("user_info")
      ),
      mainPanel(
        h4("App Content"),
        textOutput("content")
      )
    )
  )
  
  server <- function(input, output, session) {
    # Get authentication info once at startup
    user_info <- get_auth_info()
    user_cache <- create_user_cache(user_info)
    
    # Display user information
    output$user_info <- renderPrint({
      list(
        user = user_info$user_id,
        groups = user_info$user_groups,
        team = user_info$team_name
      )
    })
    
    # Check permissions
    output$content <- renderText({
      if (has_group(user_info, c("analysts", "admin"))) {
        "Welcome! You have access to this content."
      } else {
        "Access denied. You need 'analysts' or 'admin' group membership."
      }
    })
  }
  
  shinyApp(ui = ui, server = server)
}
