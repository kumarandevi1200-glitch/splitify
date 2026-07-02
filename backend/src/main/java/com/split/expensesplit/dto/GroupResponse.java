package com.split.expensesplit.dto;

import java.time.LocalDateTime;
import java.util.List;

public class GroupResponse {
    private Long id;
    private String name;
    private String currency;
    private List<MemberResponse> members;
    private LocalDateTime createdAt;

    public GroupResponse() {}

    public GroupResponse(Long id, String name, String currency, List<MemberResponse> members, LocalDateTime createdAt) {
        this.id = id;
        this.name = name;
        this.currency = currency;
        this.members = members;
        this.createdAt = createdAt;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getCurrency() {
        return currency;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }

    public List<MemberResponse> getMembers() {
        return members;
    }

    public void setMembers(List<MemberResponse> members) {
        this.members = members;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
