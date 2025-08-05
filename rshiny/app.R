library(shiny)
library(ggplot2)
library(DT)

# ============================================
# Authentication and Session Management Module
# ============================================

# Function to extract ShinyProxy authentication headers
get_shinyproxy_auth <- function(session) {
  headers <- session$request
  
  # Extract user information from ShinyProxy headers
  user_info <- list(
    user_id = headers$HTTP_X_SP_USERID,
    username = headers$HTTP_X_SP_USERNAME,
    email = headers$HTTP_X_SP_EMAIL,
    groups = if(!is.null(headers$HTTP_X_SP_USERGROUPS)) {
      strsplit(headers$HTTP_X_SP_USERGROUPS, ",")[[1]]
    } else {
      character(0)
    },
    given_name = headers$HTTP_X_SP_GIVENNAME,
    family_name = headers$HTTP_X_SP_FAMILYNAME,
    display_name = headers$HTTP_X_SP_DISPLAYNAME,
    session_id = headers$HTTP_X_SP_SESSIONID,
    proxy_id = headers$HTTP_X_SP_PROXYID,
    team = headers$HTTP_X_SP_TEAM,
    environment = headers$HTTP_X_SP_ENVIRONMENT,
    token = gsub("Bearer ", "", headers$HTTP_AUTHORIZATION)
  )
  
  # Check pre-initialization mode
  pre_init_mode <- Sys.getenv("PRE_INIT_MODE", "false")
  
  # Handle pre-init mode or missing authentication
  if (pre_init_mode == "true" && is.null(user_info$user_id)) {
    # Container is pre-initialized but no user assigned yet
    return(list(
      authenticated = FALSE,
      pre_init = TRUE,
      message = "Container in pre-initialization mode, waiting for user assignment"
    ))
  }
  
  # Check if user is authenticated
  if (is.null(user_info$user_id) || user_info$user_id == "") {
    return(list(
      authenticated = FALSE,
      pre_init = FALSE,
      message = "User not authenticated. Please login through ShinyProxy."
    ))
  }
  
  # User is authenticated
  user_info$authenticated <- TRUE
  user_info$pre_init <- FALSE
  
  return(user_info)
}

# Function to check authorization based on groups
check_user_authorization <- function(user_info, required_groups = NULL) {
  if (is.null(required_groups) || length(required_groups) == 0) {
    return(TRUE)
  }
  
  if (any(user_info$groups %in% required_groups)) {
    return(TRUE)
  }
  
  return(FALSE)
}

# Function to get user-specific data directory (for shared containers)
get_user_data_directory <- function(user_info) {
  # Base directory for user data
  base_dir <- "/tmp/shinyproxy_user_data"
  
  # Create user-specific directory
  user_dir <- file.path(base_dir, user_info$user_id)
  
  if (!dir.exists(user_dir)) {
    dir.create(user_dir, recursive = TRUE, mode = "0700")
  }
  
  return(user_dir)
}

# Function to log user activities
log_user_activity <- function(user_info, action, details = "") {
  log_dir <- "/var/log/shiny-app"
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }
  
  log_file <- file.path(log_dir, "user_activity.log")
  
  log_entry <- sprintf(
    "[%s] USER: %s (%s) | SESSION: %s | ACTION: %s | DETAILS: %s | TEAM: %s | ENV: %s",
    Sys.time(),
    user_info$user_id,
    user_info$email,
    user_info$session_id,
    action,
    details,
    user_info$team,
    user_info$environment
  )
  
  tryCatch({
    write(log_entry, file = log_file, append = TRUE)
  }, error = function(e) {
    message("Failed to write log: ", e$message)
  })
}

# Function to cleanup user session
cleanup_user_session <- function(user_info) {
  # Clean up user-specific temporary files
  user_dir <- file.path("/tmp/shinyproxy_user_data", user_info$user_id)
  
  if (dir.exists(user_dir)) {
    unlink(user_dir, recursive = TRUE)
  }
  
  # Log session end
  log_user_activity(user_info, "SESSION_END", "User session cleanup completed")
}

# ============================================
# Main Application UI
# ============================================

ui <- fluidPage(
  # Add custom CSS for authentication status
  tags$head(
    tags$style(HTML("
      .auth-status {
        padding: 10px;
        margin-bottom: 20px;
        border-radius: 5px;
      }
      .auth-success {
        background-color: #d4edda;
        border: 1px solid #c3e6cb;
        color: #155724;
      }
      .auth-error {
        background-color: #f8d7da;
        border: 1px solid #f5c6cb;
        color: #721c24;
      }
      .user-info-panel {
        background-color: #f8f9fa;
        padding: 15px;
        border-radius: 5px;
        margin-bottom: 20px;
      }
    "))
  ),
  
  # Application title
  titlePanel("Multiple Linear Regression Dashboard - Authenticated"),
  
  # Authentication status panel
  div(class = "user-info-panel",
    h4("User Information"),
    verbatimTextOutput("auth_status"),
    uiOutput("user_details")
  ),
  
  # Main application (shown only when authenticated)
  conditionalPanel(
    condition = "output.is_authenticated == 'true'",
    
    sidebarLayout(
      sidebarPanel(
        h3("Data Upload"),
        fileInput("file", "Upload CSV File", accept = ".csv"),
        
        # Display allowed groups for this app
        div(
          style = "background-color: #e9ecef; padding: 10px; border-radius: 5px; margin: 10px 0;",
          h5("Access Information"),
          textOutput("access_groups")
        ),
        
        hr(),
        
        h3("Model Configuration"),
        selectInput("dependent", "Select Dependent Variable", choices = NULL),
        selectInput("independent", "Select Independent Variables", 
                   choices = NULL, multiple = TRUE),
        actionButton("run_model", "Run Model", class = "btn-primary"),
        
        hr(),
        
        h3("Prediction"),
        uiOutput("prediction_inputs"),
        actionButton("predict", "Predict", class = "btn-success"),
        
        hr(),
        
        h3("Session Management"),
        actionButton("save_session", "Save Session", class = "btn-info"),
        actionButton("load_session", "Load Session", class = "btn-warning"),
        
        # Container information
        hr(),
        h5("Container Information"),
        verbatimTextOutput("container_info")
      ),
      
      mainPanel(
        tabsetPanel(
          tabPanel("Model Summary",
            h3("Model Summary"),
            verbatimTextOutput("model_summary"),
            
            h3("Model Coefficients"),
            DT::dataTableOutput("coefficients_table")
          ),
          
          tabPanel("Diagnostics",
            h3("Model Diagnostics"),
            plotOutput("diagnostic_plot", height = "600px"),
            
            h3("Residual Analysis"),
            plotOutput("residual_plot", height = "400px")
          ),
          
          tabPanel("Predictions",
            h3("Prediction Results"),
            tableOutput("prediction_results"),
            
            h3("Prediction Visualization"),
            plotOutput("prediction_plot")
          ),
          
          tabPanel("Audit Log",
            h3("User Activity Log"),
            DT::dataTableOutput("activity_log")
          )
        )
      )
    )
  ),
  
  # Show error message when not authenticated
  conditionalPanel(
    condition = "output.is_authenticated != 'true'",
    div(class = "auth-status auth-error",
      h3("Authentication Required"),
      p("You must be authenticated through ShinyProxy to access this application."),
      p("If you're seeing this message, please ensure you're accessing the app through ShinyProxy.")
    )
  )
)

# ============================================
# Server Logic
# ============================================

server <- function(input, output, session) {
  
  # ========== Authentication Management ==========
  
  # Get user information from ShinyProxy headers
  user_info <- reactive({
    info <- get_shinyproxy_auth(session)
    
    if (info$authenticated) {
      # Log successful authentication
      log_user_activity(info, "LOGIN", "User authenticated successfully")
      
      # Create user data directory
      info$data_dir <- get_user_data_directory(info)
    }
    
    return(info)
  })
  
  # Check if user is authenticated
  output$is_authenticated <- reactive({
    if (user_info()$authenticated) "true" else "false"
  })
  outputOptions(output, "is_authenticated", suspendWhenHidden = FALSE)
  
  # Display authentication status
  output$auth_status <- renderPrint({
    info <- user_info()
    if (info$authenticated) {
      cat("Authentication Status: SUCCESS\n")
      cat("User ID:", info$user_id, "\n")
      cat("Username:", info$username, "\n")
      cat("Email:", info$email, "\n")
      cat("Session ID:", info$session_id, "\n")
    } else {
      cat("Authentication Status: FAILED\n")
      if (info$pre_init) {
        cat("Reason: Container in pre-initialization mode\n")
      } else {
        cat("Reason:", info$message, "\n")
      }
    }
  })
  
  # Display user details
  output$user_details <- renderUI({
    req(user_info()$authenticated)
    info <- user_info()
    
    tags$div(
      tags$p(tags$strong("Display Name: "), info$display_name),
      tags$p(tags$strong("Groups: "), paste(info$groups, collapse = ", ")),
      tags$p(tags$strong("Team: "), info$team),
      tags$p(tags$strong("Environment: "), info$environment),
      tags$p(tags$strong("Data Directory: "), info$data_dir)
    )
  })
  
  # Display container information
  output$container_info <- renderPrint({
    cat("App ID:", Sys.getenv("APP_ID", "unknown"), "\n")
    cat("App Type:", Sys.getenv("APP_TYPE", "shiny"), "\n")
    cat("Pre-init Mode:", Sys.getenv("PRE_INIT_MODE", "false"), "\n")
    cat("Container ID:", Sys.getenv("HOSTNAME", "unknown"), "\n")
    cat("AWS Region:", Sys.getenv("AWS_REGION", "unknown"), "\n")
    cat("S3 Bucket:", Sys.getenv("S3_BUCKET", "unknown"), "\n")
  })
  
  # Display access groups
  output$access_groups <- renderText({
    info <- user_info()
    if (info$authenticated) {
      # Check if user has required groups (example groups)
      required_groups <- c("data-scientists", "analysts", "ml-engineers")
      has_access <- check_user_authorization(info, required_groups)
      
      if (has_access) {
        paste("You have access. Your groups:", paste(info$groups, collapse = ", "))
      } else {
        paste("Limited access. Required groups:", paste(required_groups, collapse = ", "))
      }
    } else {
      "Not authenticated"
    }
  })
  
  # ========== Activity Logging ==========
  
  activity_log_data <- reactiveVal(data.frame(
    Timestamp = character(),
    Action = character(),
    Details = character(),
    stringsAsFactors = FALSE
  ))
  
  log_activity <- function(action, details = "") {
    req(user_info()$authenticated)
    
    # Log to file
    log_user_activity(user_info(), action, details)
    
    # Update in-memory log for display
    current_log <- activity_log_data()
    new_entry <- data.frame(
      Timestamp = as.character(Sys.time()),
      Action = action,
      Details = details,
      stringsAsFactors = FALSE
    )
    activity_log_data(rbind(new_entry, current_log))
  }
  
  output$activity_log <- DT::renderDataTable({
    activity_log_data()
  }, options = list(pageLength = 10))
  
  # ========== Main Application Logic ==========
  
  # Reactive to load data with user isolation
  data <- reactive({
    req(input$file)
    req(user_info()$authenticated)
    
    # Save uploaded file to user's directory
    user_dir <- user_info()$data_dir
    file_path <- file.path(user_dir, "uploaded_data.csv")
    file.copy(input$file$datapath, file_path, overwrite = TRUE)
    
    # Log file upload
    log_activity("FILE_UPLOAD", input$file$name)
    
    # Read and return data
    read.csv(file_path)
  })
  
  # Update variable selection based on uploaded data
  observe({
    req(data())
    updateSelectInput(session, "dependent", choices = names(data()))
    updateSelectInput(session, "independent", choices = names(data()))
  })
  
  # Reactive to build model
  model <- eventReactive(input$run_model, {
    req(input$dependent, input$independent)
    req(user_info()$authenticated)
    
    # Log model run
    log_activity("MODEL_RUN", paste("Dependent:", input$dependent, 
                                   "Independent:", paste(input$independent, collapse = ", ")))
    
    formula <- as.formula(paste(input$dependent, "~", 
                               paste(input$independent, collapse = "+")))
    lm(formula, data = data())
  })
  
  # Display model summary
  output$model_summary <- renderPrint({
    req(model())
    summary(model())
  })
  
  # Display coefficients table
  output$coefficients_table <- DT::renderDataTable({
    req(model())
    coef_summary <- summary(model())$coefficients
    data.frame(
      Variable = rownames(coef_summary),
      Estimate = round(coef_summary[, "Estimate"], 4),
      Std_Error = round(coef_summary[, "Std. Error"], 4),
      t_value = round(coef_summary[, "t value"], 4),
      p_value = round(coef_summary[, "Pr(>|t|)"], 4)
    )
  }, options = list(pageLength = 15))
  
  # Diagnostic plots
  output$diagnostic_plot <- renderPlot({
    req(model())
    par(mfrow = c(2, 2))
    plot(model())
  })
  
  # Residual plot
  output$residual_plot <- renderPlot({
    req(model())
    
    residuals <- residuals(model())
    fitted <- fitted(model())
    
    ggplot(data.frame(fitted = fitted, residuals = residuals), 
           aes(x = fitted, y = residuals)) +
      geom_point(alpha = 0.6) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
      geom_smooth(method = "loess", se = TRUE, color = "blue") +
      labs(title = "Residuals vs Fitted Values",
           x = "Fitted Values",
           y = "Residuals") +
      theme_minimal()
  })
  
  # Generate prediction inputs dynamically
  output$prediction_inputs <- renderUI({
    req(model())
    lapply(input$independent, function(var) {
      # Get the range of values for the variable
      var_range <- range(data()[[var]], na.rm = TRUE)
      mean_val <- mean(data()[[var]], na.rm = TRUE)
      
      numericInput(var, 
                  label = paste0(var, " (Range: ", round(var_range[1], 2), 
                                " - ", round(var_range[2], 2), ")"),
                  value = round(mean_val, 2))
    })
  })
  
  # Predict new values
  prediction <- eventReactive(input$predict, {
    req(model())
    req(user_info()$authenticated)
    
    # Create new data for prediction
    newdata <- as.data.frame(lapply(input$independent, function(var) input[[var]]))
    colnames(newdata) <- input$independent
    
    # Log prediction
    log_activity("PREDICTION", paste("Values:", 
                                    paste(input$independent, "=", 
                                          sapply(input$independent, function(x) input[[x]]), 
                                          collapse = ", ")))
    
    # Make prediction with confidence intervals
    pred <- predict(model(), newdata = newdata, interval = "confidence", level = 0.95)
    
    # Return prediction with input values
    cbind(newdata, pred)
  })
  
  # Display prediction results
  output$prediction_results <- renderTable({
    req(prediction())
    pred_df <- as.data.frame(prediction())
    
    # Round numeric columns
    numeric_cols <- sapply(pred_df, is.numeric)
    pred_df[numeric_cols] <- round(pred_df[numeric_cols], 4)
    
    pred_df
  })
  
  # Prediction visualization
  output$prediction_plot <- renderPlot({
    req(prediction())
    req(length(input$independent) == 1)  # Only for single predictor
    
    # Get the predictor variable name
    pred_var <- input$independent[1]
    
    # Create prediction data frame
    pred_range <- seq(min(data()[[pred_var]], na.rm = TRUE),
                     max(data()[[pred_var]], na.rm = TRUE),
                     length.out = 100)
    
    pred_data <- data.frame(x = pred_range)
    colnames(pred_data) <- pred_var
    
    pred_values <- predict(model(), newdata = pred_data, interval = "confidence")
    pred_data$fit <- pred_values[, "fit"]
    pred_data$lwr <- pred_values[, "lwr"]
    pred_data$upr <- pred_values[, "upr"]
    
    # Current prediction point
    current_x <- input[[pred_var]]
    current_pred <- prediction()
    
    ggplot(pred_data, aes(x = pred_range)) +
      geom_ribbon(aes(ymin = lwr, ymax = upr), alpha = 0.3, fill = "blue") +
      geom_line(aes(y = fit), color = "blue", size = 1) +
      geom_point(data = data.frame(x = current_x, y = current_pred$fit),
                aes(x = x, y = y), color = "red", size = 3) +
      labs(title = paste("Prediction for", input$dependent),
           x = pred_var,
           y = input$dependent) +
      theme_minimal()
  })
  
  # ========== Session Management ==========
  
  # Save session to user's directory
  observeEvent(input$save_session, {
    req(user_info()$authenticated)
    req(model())
    
    user_dir <- user_info()$data_dir
    session_file <- file.path(user_dir, "model_session.rds")
    
    session_data <- list(
      model = model(),
      dependent = input$dependent,
      independent = input$independent,
      data = data(),
      timestamp = Sys.time(),
      user = user_info()$user_id
    )
    
    saveRDS(session_data, session_file)
    
    log_activity("SESSION_SAVE", "Model session saved")
    
    showNotification("Session saved successfully!", type = "success")
  })
  
  # Load session from user's directory
  observeEvent(input$load_session, {
    req(user_info()$authenticated)
    
    user_dir <- user_info()$data_dir
    session_file <- file.path(user_dir, "model_session.rds")
    
    if (file.exists(session_file)) {
      session_data <- readRDS(session_file)
      
      # Verify it's the same user's session
      if (session_data$user == user_info()$user_id) {
        # Update UI elements
        updateSelectInput(session, "dependent", selected = session_data$dependent)
        updateSelectInput(session, "independent", selected = session_data$independent)
        
        log_activity("SESSION_LOAD", paste("Session from", session_data$timestamp))
        
        showNotification("Session loaded successfully!", type = "success")
      } else {
        showNotification("Cannot load another user's session!", type = "error")
      }
    } else {
      showNotification("No saved session found!", type = "warning")
    }
  })
  
  # ========== Session Cleanup ==========
  
  # Clean up when session ends
  session$onSessionEnded(function() {
    if (user_info()$authenticated) {
      cleanup_user_session(user_info())
    }
  })
}

# Run the application
shinyApp(ui = ui, server = server)
