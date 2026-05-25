package com.learneks.teamboard.service;

import com.learneks.teamboard.model.Post;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * All EFS file operations go through this service.
 *
 * EFS structure:
 *   /mnt/efs/teams/devops/<uuid>.txt
 *   /mnt/efs/teams/qa/<uuid>.txt
 *
 * Each .txt file format:
 *   id: <uuid>
 *   title: <title>
 *   author: <username>
 *   team: <team>
 *   createdAt: <ISO datetime>
 *
 *   <message body>
 */
@Service
public class PostService {

    private static final Logger log = LoggerFactory.getLogger(PostService.class);

    private static final DateTimeFormatter FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");

    @Value("${efs.mount.path:/mnt/efs}")
    private String efsMountPath;

    // ── Directory helpers ──────────────────────────────────────────────────

    private Path postDir(String team) {
        return Paths.get(efsMountPath, "teams", team);
    }

    private Path postFile(String team, String id) {
        return postDir(team).resolve(id + ".txt");
    }

    private void ensurePostDir(String team) throws IOException {
        Files.createDirectories(postDir(team));
    }

    // ── Write ──────────────────────────────────────────────────────────────

    public Post createPost(String title, String message, String author, String team)
            throws IOException {
        ensurePostDir(team);

        String id = UUID.randomUUID().toString();
        LocalDateTime now = LocalDateTime.now();

        String content = buildFileContent(id, title, author, team, now, message);
        Files.writeString(postFile(team, id), content, StandardOpenOption.CREATE_NEW);

        return new Post(id, title, author, team, now, message);
    }

    // ── Read ───────────────────────────────────────────────────────────────

    public List<Post> listPosts(String team) throws IOException {
        ensurePostDir(team);

        try (var stream = Files.list(postDir(team))) {
            return stream
                    .filter(p -> p.toString().endsWith(".txt"))
                    .map(this::parseFile)
                    .filter(Optional::isPresent)
                    .map(Optional::get)
                    .sorted(Comparator.comparing(Post::getCreatedAt).reversed())
                    .collect(Collectors.toList());
        }
    }

    // ── Delete ─────────────────────────────────────────────────────────────

    public boolean deletePost(String id, String team, String requestingUser) throws IOException {
        UUID parsed;
        try {
            parsed = UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            log.warn("Delete rejected: invalid UUID '{}' from user '{}'", id, requestingUser);
            return false;
        }

        Path file = postFile(team, parsed.toString());
        if (!Files.exists(file)) {
            log.warn("Delete failed: file not found '{}' requested by '{}'", file, requestingUser);
            return false;
        }

        Optional<Post> post = parseFile(file);
        if (post.isEmpty()) return false;

        if (!post.get().getAuthor().equals(requestingUser)) {
            log.warn("Delete rejected: '{}' tried to delete post owned by '{}'",
                    requestingUser, post.get().getAuthor());
            return false;
        }

        Files.delete(file);
        return true;
    }

    // ── File format ────────────────────────────────────────────────────────

    private String buildFileContent(String id, String title, String author,
                                    String team, LocalDateTime createdAt, String message) {
        return "id: " + id + "\n"
             + "title: " + title + "\n"
             + "author: " + author + "\n"
             + "team: " + team + "\n"
             + "createdAt: " + createdAt.format(FORMATTER) + "\n"
             + "\n"
             + message;
    }

    private Optional<Post> parseFile(Path file) {
        try {
            String content = Files.readString(file);
            String[] parts = content.split("\n\n", 2);
            if (parts.length < 2) {
                log.warn("Malformed post file (no header/body separator): {}", file);
                return Optional.empty();
            }

            Map<String, String> headers = new LinkedHashMap<>();
            for (String line : parts[0].split("\n")) {
                int colon = line.indexOf(": ");
                if (colon > 0) {
                    headers.put(line.substring(0, colon).trim(),
                                line.substring(colon + 2).trim());
                }
            }

            String id        = headers.getOrDefault("id", "");
            String title     = headers.getOrDefault("title", "");
            String author    = headers.getOrDefault("author", "");
            String team      = headers.getOrDefault("team", "");
            String createdAt = headers.getOrDefault("createdAt", "");
            String message   = parts[1].trim();

            if (id.isEmpty() || title.isEmpty() || author.isEmpty()) {
                log.warn("Malformed post file (missing required headers): {}", file);
                return Optional.empty();
            }

            LocalDateTime dt = LocalDateTime.parse(createdAt, FORMATTER);
            return Optional.of(new Post(id, title, author, team, dt, message));

        } catch (Exception e) {
            log.warn("Failed to parse post file '{}': {}", file, e.getMessage());
            return Optional.empty();
        }
    }
}
