package com.learneks.teamboard.controller;

import com.learneks.teamboard.model.Post;
import com.learneks.teamboard.service.PostService;
import com.learneks.teamboard.service.UserService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;

@Controller
@RequestMapping("/board")
public class BoardController {

    private final PostService postService;
    private final UserService userService;

    @Value("${efs.mount.path:/mnt/efs}")
    private String efsMountPath;

    public BoardController(PostService postService, UserService userService) {
        this.postService = postService;
        this.userService = userService;
    }

    // ── GET /board ─────────────────────────────────────────────────────────

    @GetMapping
    public String board(Principal principal, Model model) throws Exception {
        String username = principal.getName();
        String team     = userService.getTeamForUser(username);
        List<Post> posts = postService.listPosts(team);

        model.addAttribute("username", username);
        model.addAttribute("team", team);
        model.addAttribute("posts", posts);
        model.addAttribute("podName", System.getenv().getOrDefault("HOSTNAME", "local"));
        model.addAttribute("efsMountPath", efsMountPath);

        return "board";
    }

    // ── POST /board/post ───────────────────────────────────────────────────

    @PostMapping("/post")
    public String createPost(@RequestParam String title,
                             @RequestParam String message,
                             Principal principal) throws Exception {

        String username = principal.getName();
        String team     = userService.getTeamForUser(username);

        if (title == null || title.isBlank())     return "redirect:/board?error=empty-title";
        if (message == null || message.isBlank()) return "redirect:/board?error=empty-message";
        if (title.length() > 100)                 return "redirect:/board?error=title-too-long";
        if (message.length() > 1000)              return "redirect:/board?error=message-too-long";
        if (title.contains("\n") || title.contains("\r")) return "redirect:/board?error=invalid-title";

        postService.createPost(title.trim(), message.trim(), username, team);
        return "redirect:/board";
    }

    // ── POST /board/post/{id}/delete ───────────────────────────────────────

    @PostMapping("/post/{id}/delete")
    public String deletePost(@PathVariable String id,
                             Principal principal) throws Exception {

        String username = principal.getName();
        String team     = userService.getTeamForUser(username);

        boolean deleted = postService.deletePost(id, team, username);
        if (!deleted) return "redirect:/board?error=delete-not-allowed";
        return "redirect:/board";
    }
}
