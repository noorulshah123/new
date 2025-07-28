# app.R - Test Shiny application to verify setup
library(shiny)

# Define UI
ui <- fluidPage(
    titlePanel("Shiny Server Test Application"),
    
    sidebarLayout(
        sidebarPanel(
            h3("System Information"),
            verbatimTextOutput("sysinfo"),
            
            hr(),
            
            h3("Environment Variables"),
            h4("S3 Configuration:"),
            verbatimTextOutput("s3_env"),
            
            h4("Snowflake Configuration:"),
            verbatimTextOutput("snow_env"),
            
            hr(),
            
            h3("Directory Permissions"),
            verbatimTextOutput("permissions")
        ),
        
        mainPanel(
            h3("R Session Info"),
            verbatimTextOutput("sessioninfo"),
            
            hr(),
            
            h3("Installed Packages"),
            DT::dataTableOutput("packages"),
            
            hr(),
            
            h3("Test Operations"),
            actionButton("test_write", "Test Write Permissions"),
            verbatimTextOutput("write_result"),
            
            hr(),
            
            h3("Python Integration"),
            verbatimTextOutput("python_info")
        )
    )
)

# Define server logic
server <- function(input, output, session) {
    
    # System information
    output$sysinfo <- renderPrint({
        list(
            "R Version" = R.version.string,
            "Platform" = R.version$platform,
            "User" = Sys.info()["user"],
            "Hostname" = Sys.info()["nodename"],
            "Working Directory" = getwd(),
            "Temp Directory" = tempdir()
        )
    })
    
    # S3 Environment variables
    output$s3_env <- renderPrint({
        env_vars <- Sys.getenv()
        s3_vars <- env_vars[grep("^(S3_|AWS_)", names(env_vars))]
        if(length(s3_vars) > 0) {
            # Mask sensitive values
            s3_vars <- sapply(s3_vars, function(x) {
                if(grepl("SECRET|PASSWORD|KEY", names(x), ignore.case = TRUE)) {
                    return("***MASKED***")
                }
                return(x)
            })
            s3_vars
        } else {
            "No S3/AWS environment variables found"
        }
    })
    
    # Snowflake Environment variables
    output$snow_env <- renderPrint({
        env_vars <- Sys.getenv()
        snow_vars <- env_vars[grep("^SNOWFLAKE_", names(env_vars))]
        if(length(snow_vars) > 0) {
            # Mask password
            if("SNOWFLAKE_PASSWORD" %in% names(snow_vars)) {
                snow_vars["SNOWFLAKE_PASSWORD"] <- "***MASKED***"
            }
            snow_vars
        } else {
            "No Snowflake environment variables found"
        }
    })
    
    # Directory permissions
    output$permissions <- renderPrint({
        dirs <- c(
            "/srv/shiny-server/app",
            "/var/log/shiny-server",
            "/var/lib/shiny-server",
            "/var/lib/shiny-server/bookmarks",
            "/tmp/shiny-server"
        )
        
        check_dir <- function(dir) {
            if(dir.exists(dir)) {
                info <- file.info(dir)
                list(
                    exists = TRUE,
                    writable = file.access(dir, 2) == 0,
                    mode = info$mode,
                    owner = info$uid
                )
            } else {
                list(exists = FALSE)
            }
        }
        
        sapply(dirs, check_dir, simplify = FALSE)
    })
    
    # Session info
    output$sessioninfo <- renderPrint({
        sessionInfo()
    })
    
    # Installed packages
    output$packages <- DT::renderDataTable({
        pkgs <- installed.packages()[, c("Package", "Version", "LibPath")]
        DT::datatable(pkgs, options = list(pageLength = 10))
    })
    
    # Test write permissions
    observeEvent(input$test_write, {
        output$write_result <- renderPrint({
            results <- list()
            
            # Test bookmark directory
            tryCatch({
                test_file <- "/var/lib/shiny-server/bookmarks/test.txt"
                writeLines("Test write", test_file)
                file.remove(test_file)
                results$bookmarks <- "SUCCESS: Can write to bookmarks directory"
            }, error = function(e) {
                results$bookmarks <- paste("FAIL:", e$message)
            })
            
            # Test temp directory
            tryCatch({
                test_file <- file.path(tempdir(), "test.txt")
                writeLines("Test write", test_file)
                file.remove(test_file)
                results$temp <- "SUCCESS: Can write to temp directory"
            }, error = function(e) {
                results$temp <- paste("FAIL:", e$message)
            })
            
            results
        })
    })
    
    # Python information
    output$python_info <- renderPrint({
        if(requireNamespace("reticulate", quietly = TRUE)) {
            tryCatch({
                reticulate::py_config()
            }, error = function(e) {
                paste("Python integration error:", e$message)
            })
        } else {
            "reticulate package not installed"
        }
    })
}

# Run the application
shinyApp(ui = ui, server = server)
