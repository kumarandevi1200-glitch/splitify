package com.split.expensesplit.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public class SettlementCreateRequest {

    @NotNull(message = "Recipient user ID is required")
    private Long paidToId;

    @NotNull(message = "Amount is required")
    @DecimalMin(value = "0.01", message = "Amount must be greater than 0")
    private BigDecimal amount;

    private String note;

    public SettlementCreateRequest() {}

    public SettlementCreateRequest(Long paidToId, BigDecimal amount, String note) {
        this.paidToId = paidToId;
        this.amount = amount;
        this.note = note;
    }

    public Long getPaidToId() {
        return paidToId;
    }

    public void setPaidToId(Long paidToId) {
        this.paidToId = paidToId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }
}
