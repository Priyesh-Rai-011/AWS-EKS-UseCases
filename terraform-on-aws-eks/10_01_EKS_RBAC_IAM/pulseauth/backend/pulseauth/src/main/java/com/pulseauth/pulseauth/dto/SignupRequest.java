package com.pulseauth.pulseauth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class SignupRequest {
    @NotBlank private String name;
    @Email @NotBlank private String email;
    @NotBlank private String password;
}
