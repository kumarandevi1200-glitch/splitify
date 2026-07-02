package com.split.expensesplit.dto;

public class MemberResponse {
    private Long id;
    private String email;

    public MemberResponse() {}

    public MemberResponse(Long id, String email) {
        this.id = id;
        this.email = email;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}
