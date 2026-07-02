package com.split.expensesplit.dto;

import java.time.LocalDateTime;

public class InviteCodeResponse {
    private String code;
    private LocalDateTime expiresAt;
    private Integer maxUses;
    private Integer usesCount;

    public InviteCodeResponse() {}

    public InviteCodeResponse(String code, LocalDateTime expiresAt, Integer maxUses, Integer usesCount) {
        this.code = code;
        this.expiresAt = expiresAt;
        this.maxUses = maxUses;
        this.usesCount = usesCount;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(LocalDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public Integer getMaxUses() {
        return maxUses;
    }

    public void setMaxUses(Integer maxUses) {
        this.maxUses = maxUses;
    }

    public Integer getUsesCount() {
        return usesCount;
    }

    public void setUsesCount(Integer usesCount) {
        this.usesCount = usesCount;
    }
}
