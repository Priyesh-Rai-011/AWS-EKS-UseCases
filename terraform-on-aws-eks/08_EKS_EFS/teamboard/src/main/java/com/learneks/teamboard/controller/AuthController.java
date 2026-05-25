package com.learneks.teamboard.controller;

import com.learneks.teamboard.service.UserService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.Set;

@Controller
public class AuthController {

    private static final java.util.regex.Pattern USERNAME_PATTERN =
            java.util.regex.Pattern.compile("^[A-Za-z0-9_-]{3,30}$");

    private static final Set<String> VALID_TEAMS = Set.of("devops", "qa");

    private final UserService userService;

    public AuthController(UserService userService) {
        this.userService = userService;
    }

    // ── Login ──────────────────────────────────────────────────────────────

    @GetMapping("/login")
    public String loginPage(@RequestParam(required = false) String error,
                            @RequestParam(required = false) String logout,
                            Model model) {
        if (error != null)  model.addAttribute("error", "Invalid username or password.");
        if (logout != null) model.addAttribute("message", "You have been logged out.");
        return "login";
    }

    // ── Register ───────────────────────────────────────────────────────────

    @GetMapping("/register")
    public String registerPage() {
        return "register";
    }

    @PostMapping("/register")
    public String register(@RequestParam String username,
                           @RequestParam String password,
                           @RequestParam String team,
                           Model model) {

        if (!USERNAME_PATTERN.matcher(username).matches()) {
            model.addAttribute("error",
                "Username must be 3-30 characters: letters, digits, _ or - only.");
            return "register";
        }

        if (password == null || password.length() < 4) {
            model.addAttribute("error", "Password must be at least 4 characters.");
            return "register";
        }

        if (!VALID_TEAMS.contains(team)) {
            model.addAttribute("error", "Team must be 'devops' or 'qa'.");
            return "register";
        }

        try {
            userService.register(username, password, team);
            return "redirect:/login?registered=true";
        } catch (IllegalArgumentException e) {
            model.addAttribute("error", e.getMessage());
            return "register";
        }
    }
}
