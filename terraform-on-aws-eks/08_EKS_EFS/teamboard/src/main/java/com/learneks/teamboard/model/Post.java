package com.learneks.teamboard.model;

import java.time.LocalDateTime;

/**
 * NOT a DB entity.
 * Represents one .txt file read from EFS:
 *
 *   id: <uuid>
 *   title: <title>
 *   author: <username>
 *   createdAt: <ISO datetime>
 *
 *   <message body>
 */
public class Post {

    private String id;          // UUID — also the filename: <uuid>.txt
    private String title;
    private String author;
    private String team;
    private LocalDateTime createdAt;
    private String message;

    public Post() {}

    public Post(String id, String title, String author, String team,
                LocalDateTime createdAt, String message) {
        this.id = id;
        this.title = title;
        this.author = author;
        this.team = team;
        this.createdAt = createdAt;
        this.message = message;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getAuthor() { return author; }
    public void setAuthor(String author) { this.author = author; }

    public String getTeam() { return team; }
    public void setTeam(String team) { this.team = team; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
