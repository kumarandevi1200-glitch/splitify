package com.split.expensesplit.dto;

import jakarta.validation.constraints.NotBlank;

public class JoinGroupRequest {

    @NotBlank(message = "Invite code is required")
    private String code;

    public JoinGroupRequest() {}

    public JoinGroupRequest(String code) {
        this.code = code;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }
}
