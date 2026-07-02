package com.split.expensesplit.dto;

import java.math.BigDecimal;
import java.util.List;

public class ReportResponse {
    private BigDecimal totalSpend;
    private List<MemberBalance> balances;
    private List<DebtResponse> directDebts;
    private List<DebtResponse> optimalTransactions;
    private List<CategoryBreakdown> categoryBreakdown;
    private List<DailySpend> dailySpend;

    public ReportResponse() {}

    public ReportResponse(BigDecimal totalSpend, List<MemberBalance> balances, List<DebtResponse> directDebts,
                          List<DebtResponse> optimalTransactions, List<CategoryBreakdown> categoryBreakdown, List<DailySpend> dailySpend) {
        this.totalSpend = totalSpend;
        this.balances = balances;
        this.directDebts = directDebts;
        this.optimalTransactions = optimalTransactions;
        this.categoryBreakdown = categoryBreakdown;
        this.dailySpend = dailySpend;
    }

    public BigDecimal getTotalSpend() {
        return totalSpend;
    }

    public void setTotalSpend(BigDecimal totalSpend) {
        this.totalSpend = totalSpend;
    }

    public List<MemberBalance> getBalances() {
        return balances;
    }

    public void setBalances(List<MemberBalance> balances) {
        this.balances = balances;
    }

    public List<DebtResponse> getDirectDebts() {
        return directDebts;
    }

    public void setDirectDebts(List<DebtResponse> directDebts) {
        this.directDebts = directDebts;
    }

    public List<DebtResponse> getOptimalTransactions() {
        return optimalTransactions;
    }

    public void setOptimalTransactions(List<DebtResponse> optimalTransactions) {
        this.optimalTransactions = optimalTransactions;
    }

    public List<CategoryBreakdown> getCategoryBreakdown() {
        return categoryBreakdown;
    }

    public void setCategoryBreakdown(List<CategoryBreakdown> categoryBreakdown) {
        this.categoryBreakdown = categoryBreakdown;
    }

    public List<DailySpend> getDailySpend() {
        return dailySpend;
    }

    public void setDailySpend(List<DailySpend> dailySpend) {
        this.dailySpend = dailySpend;
    }
}
