package com.split.expensesplit.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public class ExpenseResponse {
    private Long id;
    private BigDecimal amount;
    private String description;
    private String splitType;
    private MemberResponse payer;
    private String category;
    private LocalDateTime expenseDate;
    private boolean isDeleted;
    private Long version;
    private List<ExpenseShareResponse> shares;

    public ExpenseResponse() {}

    public ExpenseResponse(Long id, BigDecimal amount, String description, String splitType, MemberResponse payer,
                           String category, LocalDateTime expenseDate, boolean isDeleted, Long version, List<ExpenseShareResponse> shares) {
        this.id = id;
        this.amount = amount;
        this.description = description;
        this.splitType = splitType;
        this.payer = payer;
        this.category = category;
        this.expenseDate = expenseDate;
        this.isDeleted = isDeleted;
        this.version = version;
        this.shares = shares;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
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

    public MemberResponse getPayer() {
        return payer;
    }

    public void setPayer(MemberResponse payer) {
        this.payer = payer;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public LocalDateTime getExpenseDate() {
        return expenseDate;
    }

    public void setExpenseDate(LocalDateTime expenseDate) {
        this.expenseDate = expenseDate;
    }

    public boolean isDeleted() {
        return isDeleted;
    }

    public void setDeleted(boolean deleted) {
        isDeleted = deleted;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion(Long version) {
        this.version = version;
    }

    public List<ExpenseShareResponse> getShares() {
        return shares;
    }

    public void setShares(List<ExpenseShareResponse> shares) {
        this.shares = shares;
    }
}
