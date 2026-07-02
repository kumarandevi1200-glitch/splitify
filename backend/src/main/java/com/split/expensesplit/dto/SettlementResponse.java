package com.split.expensesplit.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class SettlementResponse {
    private Long id;
    private MemberResponse paidBy;
    private MemberResponse paidTo;
    private BigDecimal amount;
    private String note;
    private LocalDateTime settlementDate;

    public SettlementResponse() {}

    public SettlementResponse(Long id, MemberResponse paidBy, MemberResponse paidTo, BigDecimal amount, String note, LocalDateTime settlementDate) {
        this.id = id;
        this.paidBy = paidBy;
        this.paidTo = paidTo;
        this.amount = amount;
        this.note = note;
        this.settlementDate = settlementDate;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public MemberResponse getPaidBy() {
        return paidBy;
    }

    public void setPaidBy(MemberResponse paidBy) {
        this.paidBy = paidBy;
    }

    public MemberResponse getPaidTo() {
        return paidTo;
    }

    public void setPaidTo(MemberResponse paidTo) {
        this.paidTo = paidTo;
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

    public LocalDateTime getSettlementDate() {
        return settlementDate;
    }

    public void setSettlementDate(LocalDateTime settlementDate) {
        this.settlementDate = settlementDate;
    }
}
