package com.split.expensesplit.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.List;

public class ExpenseCreateRequest {

    @NotNull(message = "Amount is required")
    @DecimalMin(value = "0.01", message = "Amount must be greater than 0")
    private BigDecimal amount;

    @NotNull(message = "Payer ID is required")
    private Long payerId;

    @NotBlank(message = "Description is required")
    private String description;

    @NotBlank(message = "Split type is required")
    private String splitType; // EQUAL, EXACT, PERCENTAGE, SHARES

    @NotBlank(message = "Category is required")
    private String category = "General";

    @NotEmpty(message = "Participants list cannot be empty")
    @Valid
    private List<ShareRequest> shares;

    public ExpenseCreateRequest() {}

    public ExpenseCreateRequest(BigDecimal amount, Long payerId, String description, String splitType, String category, List<ShareRequest> shares) {
        this.amount = amount;
        this.payerId = payerId;
        this.description = description;
        this.splitType = splitType;
        this.category = category;
        this.shares = shares;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public Long getPayerId() {
        return payerId;
    }

    public void setPayerId(Long payerId) {
        this.payerId = payerId;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getSplitType() {
        return splitType;
    }

    public void setSplitType(String splitType) {
        this.splitType = splitType;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public List<ShareRequest> getShares() {
        return shares;
    }

    public void setShares(List<ShareRequest> shares) {
        this.shares = shares;
    }
}
