#' Settings Password Management Module
#'
#' @description Server logic for user password change functionality
#' Handles password validation, authentication, and database updates
#' Available to all users for their own password management
#'
#' @param id,input,output,session Internal parameters for {shiny}
#' @param current_user Reactive function returning current user information
#' @param alerts ReactiveValues object for managing alert messages
#'
#' @noRd
#' @import shiny
mod_settings_password_server <- function(id, current_user, alerts) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # User password change functionality
    observeEvent(input$change_password_btn, {
      showModal(modalDialog(
        title = "Change Password",
        size = "m",

        passwordInput(
          ns("current_password"),
          "Current Password",
          placeholder = "Enter current password"
        ),

        passwordInput(
          ns("new_password"),
          "New Password",
          placeholder = "Minimum 6 characters"
        ),

        passwordInput(
          ns("confirm_new_password"),
          "Confirm New Password",
          placeholder = "Re-enter new password"
        ),

        footer = div(
          actionButton(
            ns("submit_password_change"),
            "Change Password",
            icon = icon("key"),
            class = "btn-success"
          ),
          modalButton("Cancel")
        ),
        easyClose = TRUE
      ))
    })

    # Handle password change submission
    observeEvent(input$submit_password_change, {
      req(input$current_password, input$new_password, input$confirm_new_password)

      # Validate password confirmation
      if (input$new_password != input$confirm_new_password) {
        alerts$user_message <- "New passwords do not match"
        alerts$user_type <- "danger"
        return()
      }

      # Validate password length
      if (nchar(input$new_password) < 6) {
        alerts$user_message <- "New password must be at least 6 characters long"
        alerts$user_type <- "danger"
        return()
      }

      # Verify current password first
      auth_result <- authenticate_user(current_user()$email, input$current_password)

      if (!auth_result$success) {
        alerts$user_message <- "Current password is incorrect"
        alerts$user_type <- "danger"
        return()
      }

      # Update password
      result <- update_user_password(
        email = current_user()$email,
        new_password = input$new_password,
        current_user_email = current_user()$email,
        current_user_role = current_user()$role
      )

      if (result$success) {
        alerts$user_message <- "Password changed successfully"
        alerts$user_type <- "success"
        removeModal()

        # Clear password fields for security
        updateTextInput(session, "current_password", value = "")
        updateTextInput(session, "new_password", value = "")
        updateTextInput(session, "confirm_new_password", value = "")
      } else {
        alerts$user_message <- result$message
        alerts$user_type <- "danger"
      }
    })

    # Clear password fields when modal is closed without submission
    observeEvent(input$change_password_btn, {
      # Reset fields when modal is opened
      updateTextInput(session, "current_password", value = "")
      updateTextInput(session, "new_password", value = "")
      updateTextInput(session, "confirm_new_password", value = "")
    })
  })
}