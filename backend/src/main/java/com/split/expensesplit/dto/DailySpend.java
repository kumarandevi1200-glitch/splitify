package com.split.expensesplit.dto;

import java.math.BigDecimal;

public class DailySpend {
    private String date; // YYYY-MM-DD
    private BigDecimal amount;

    public DailySpend() {}

    public DailySpend(String date, BigDecimal amount) {
        this.date = date;
        this.amount = amount;
    }

    public String getDate() {
        return date;
    }

    public void setDate(String date) {
        this.date = date;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }
}
