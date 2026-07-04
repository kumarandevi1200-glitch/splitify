package com.split.expensesplit.dto;

public class AuthResponse {
    private String accessToken;
    private String refreshToken;
    private String email;
    private Long userId;
    private String name;

    public AuthResponse() {}

    public AuthResponse(String accessToken, String refreshToken, String email, Long userId, String name) {
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        this.email = email;
        this.userId = userId;
        this.name = name;
    }

    public String getAccessToken() {
        return accessToken;
    }

    public void setAccessToken(String accessToken) {
        this.accessToken = accessToken;
    }

    public String getRefreshToken() {
        return refreshToken;
    }

    public void setRefreshToken(String refreshToken) {
        this.refreshToken = refreshToken;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }
}
