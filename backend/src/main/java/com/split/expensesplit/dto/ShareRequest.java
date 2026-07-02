package com.split.expensesplit.dto;

import java.math.BigDecimal;

public class ShareRequest {
    private Long userId;
    private BigDecimal amount;
    private BigDecimal percentage;
    private BigDecimal shares;

    public ShareRequest() {}

    public ShareRequest(Long userId, BigDecimal amount, BigDecimal percentage, BigDecimal shares) {
        this.userId = userId;
        this.amount = amount;
        this.percentage = percentage;
        this.shares = shares;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
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
