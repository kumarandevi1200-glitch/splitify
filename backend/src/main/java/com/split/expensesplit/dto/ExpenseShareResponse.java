package com.split.expensesplit.dto;

import java.math.BigDecimal;

public class ExpenseShareResponse {
    private Long userId;
    private String email;
    private BigDecimal shareAmount;
    private BigDecimal percentage;
    private BigDecimal shares;

    public ExpenseShareResponse() {}

    public ExpenseShareResponse(Long userId, String email, BigDecimal shareAmount, BigDecimal percentage, BigDecimal shares) {
        this.userId = userId;
        this.email = email;
        this.shareAmount = shareAmount;
        this.percentage = percentage;
        this.shares = shares;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public BigDecimal getShareAmount() {
        return shareAmount;
    }

    public void setShareAmount(BigDecimal shareAmount) {
        this.shareAmount = shareAmount;
    }

    public BigDecimal getPercentage() {
        return percentage;
    }

    public void setPercentage(BigDecimal percentage) {
        this.percentage = percentage;
    }

    public BigDecimal getShares() {
        return shares;
    }

    public void setShares(BigDecimal shares) {
        this.shares = shares;
    }
}
