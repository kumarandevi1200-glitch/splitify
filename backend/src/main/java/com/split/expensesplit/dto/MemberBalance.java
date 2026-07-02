package com.split.expensesplit.dto;

import java.math.BigDecimal;

public class MemberBalance {
    private Long userId;
    private String email;
    private BigDecimal balance;

    public MemberBalance() {}

    public MemberBalance(Long userId, String email, BigDecimal balance) {
        this.userId = userId;
        this.email = email;
        this.balance = balance;
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

    public BigDecimal getBalance() {
        return balance;
    }

    public void setBalance(BigDecimal balance) {
        this.balance = balance;
    }
}
