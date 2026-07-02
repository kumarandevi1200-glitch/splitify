package com.split.expensesplit.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class GroupCreateRequest {

    @NotBlank(message = "Group name is required")
    @Size(max = 255, message = "Group name must be less than 255 characters")
    private String name;

    @NotBlank(message = "Group currency is required")
    @Size(max = 10, message = "Currency must be less than 10 characters")
    private String currency;

    public GroupCreateRequest() {}

    public GroupCreateRequest(String name, String currency) {
        this.name = name;
        this.currency = currency;
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
}
