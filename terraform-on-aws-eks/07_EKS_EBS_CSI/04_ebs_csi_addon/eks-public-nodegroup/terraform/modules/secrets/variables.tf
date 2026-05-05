variable "secrets" {
  description = "Map of secrets to create. Key is a logical name used to reference outputs."
  type = map(object({
    name          = string
    description   = optional(string, "")
    secret_string = string
  }))
}

variable "recovery_window_in_days" {
  description = "Days Secrets Manager waits before deleting a secret (0 = immediate, max 30)"
  type        = number
  default     = 0
}

variable "tags" {
  type    = map(string)
  default = {}
}
