package com.split.expensesplit.dto;

import java.math.BigDecimal;

public class DebtResponse {
    private MemberResponse fromUser;
    private MemberResponse toUser;
    private BigDecimal amount;

    public DebtResponse() {}

    public DebtResponse(MemberResponse fromUser, MemberResponse toUser, BigDecimal amount) {
        this.fromUser = fromUser;
        this.toUser = toUser;
        this.amount = amount;
    }

    public MemberResponse getFromUser() {
        return fromUser;
    }

    public void setFromUser(MemberResponse fromUser) {
        this.fromUser = fromUser;
    }

    public MemberResponse getToUser() {
        return toUser;
    }

    public void setToUser(MemberResponse toUser) {
        this.toUser = toUser;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }
}
