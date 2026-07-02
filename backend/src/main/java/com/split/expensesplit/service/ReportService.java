package com.split.expensesplit.service;

import com.split.expensesplit.dto.*;
import com.split.expensesplit.entity.*;
import com.split.expensesplit.exception.CustomException;
import com.split.expensesplit.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ReportService {

    @Autowired
    private GroupRepository groupRepository;

    @Autowired
    private ExpenseRepository expenseRepository;

    @Autowired
    private SettlementRepository settlementRepository;

    @Autowired
    private GroupService groupService;

    private static class MemberBalanceNode {
        User user;
        BigDecimal balance;

        MemberBalanceNode(User user, BigDecimal balance) {
            this.user = user;
            this.balance = balance;
        }

        BigDecimal getAbsBalance() {
            return balance.abs();
        }
    }

    @Transactional(readOnly = true)
    public ReportResponse generateReport(Long groupId, String email) {
        Group group = groupService.getGroupAndVerifyMembership(groupId, email);

        List<Expense> expenses = expenseRepository.findByGroupIdAndIsDeletedFalseOrderByExpenseDateDesc(groupId);
        List<Settlement> settlements = settlementRepository.findByGroupIdOrderBySettlementDateDesc(groupId);

        // 1. Calculate Net Balances per Member
        Map<Long, BigDecimal> netBalances = calculateNetBalances(group.getMembers(), expenses, settlements);

        // 2. Compute Total Spend
        BigDecimal totalSpend = expenses.stream()
                .map(Expense::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_EVEN);

        // 3. Map Member Balances DTO list
        List<MemberBalance> balancesList = group.getMembers().stream()
                .map(member -> new MemberBalance(
                        member.getId(),
                        member.getEmail(),
                        netBalances.getOrDefault(member.getId(), BigDecimal.ZERO).setScale(2, RoundingMode.HALF_EVEN)
                ))
                .sorted(Comparator.comparing(MemberBalance::getEmail))
                .collect(Collectors.toList());

        // 4. Calculate Direct/Raw Debts (Toggle = OFF)
        List<DebtResponse> directDebts = calculateDirectDebts(group.getMembers(), expenses, settlements);

        // 5. Calculate Optimal/Minimal Transactions (Toggle = ON)
        List<DebtResponse> optimalTransactions = calculateOptimalTransactions(group.getMembers(), netBalances);

        // 6. Category Breakdown
        Map<String, BigDecimal> categoryMap = new HashMap<>();
        for (Expense exp : expenses) {
            categoryMap.put(exp.getCategory(), categoryMap.getOrDefault(exp.getCategory(), BigDecimal.ZERO).add(exp.getAmount()));
        }
        List<CategoryBreakdown> categoryBreakdowns = categoryMap.entrySet().stream()
                .map(e -> new CategoryBreakdown(e.getKey(), e.getValue().setScale(2, RoundingMode.HALF_EVEN)))
                .sorted(Comparator.comparing(CategoryBreakdown::getCategory))
                .collect(Collectors.toList());

        // 7. Daily Spend Breakdown (YYYY-MM-DD)
        Map<String, BigDecimal> dailyMap = new TreeMap<>(); // Treemap keeps it sorted by date string asc
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");
        for (Expense exp : expenses) {
            String dateStr = exp.getExpenseDate().format(formatter);
            dailyMap.put(dateStr, dailyMap.getOrDefault(dateStr, BigDecimal.ZERO).add(exp.getAmount()));
        }
        List<DailySpend> dailySpends = dailyMap.entrySet().stream()
                .map(e -> new DailySpend(e.getKey(), e.getValue().setScale(2, RoundingMode.HALF_EVEN)))
                .collect(Collectors.toList());

        return new ReportResponse(
                totalSpend,
                balancesList,
                directDebts,
                optimalTransactions,
                categoryBreakdowns,
                dailySpends
        );
    }

    public Map<Long, BigDecimal> calculateNetBalances(Collection<User> members, List<Expense> expenses, List<Settlement> settlements) {
        Map<Long, BigDecimal> balances = new HashMap<>();
        
        // Initialize all member balances to zero
        for (User u : members) {
            balances.put(u.getId(), BigDecimal.ZERO);
        }

        // Add paid expenses and subtract shared parts
        for (Expense exp : expenses) {
            Long payerId = exp.getPayer().getId();
            if (balances.containsKey(payerId)) {
                balances.put(payerId, balances.get(payerId).add(exp.getAmount()));
            }

            for (ExpenseShare share : exp.getShares()) {
                Long shareUserId = share.getUser().getId();
                if (balances.containsKey(shareUserId)) {
                    balances.put(shareUserId, balances.get(shareUserId).subtract(share.getShareAmount()));
                }
            }
        }

        // Subtract settlements paid and add settlements received
        for (Settlement set : settlements) {
            Long paidById = set.getPaidBy().getId();
            Long paidToId = set.getPaidTo().getId();

            if (balances.containsKey(paidById)) {
                balances.put(paidById, balances.get(paidById).subtract(set.getAmount()));
            }
            if (balances.containsKey(paidToId)) {
                balances.put(paidToId, balances.get(paidToId).add(set.getAmount()));
            }
        }

        return balances;
    }

    private List<DebtResponse> calculateDirectDebts(Collection<User> members, List<Expense> expenses, List<Settlement> settlements) {
        // Map user list by ID for lookups
        Map<Long, User> userMap = members.stream().collect(Collectors.toMap(User::getId, u -> u));

        // Track raw pairwise debts: key: "fromId-toId", value: amount
        Map<String, BigDecimal> pairDebts = new HashMap<>();

        // Iterate over active expenses: participant owes payer share_amount
        for (Expense exp : expenses) {
            Long payerId = exp.getPayer().getId();
            for (ExpenseShare share : exp.getShares()) {
                Long participantId = share.getUser().getId();
                if (!participantId.equals(payerId)) {
                    String key = participantId + "-" + payerId;
                    pairDebts.put(key, pairDebts.getOrDefault(key, BigDecimal.ZERO).add(share.getShareAmount()));
                }
            }
        }

        // Subtract recorded settlements from the pairwise debts to reflect payments
        for (Settlement set : settlements) {
            Long fromId = set.getPaidBy().getId();
            Long toId = set.getPaidTo().getId();

            // Settle fromId -> toId reduces the debt "fromId owes toId"
            String keyDirect = fromId + "-" + toId;
            String keyReverse = toId + "-" + fromId;

            if (pairDebts.containsKey(keyDirect)) {
                BigDecimal debt = pairDebts.get(keyDirect);
                BigDecimal remaining = debt.subtract(set.getAmount());
                if (remaining.compareTo(BigDecimal.ZERO) <= 0) {
                    pairDebts.remove(keyDirect);
                    // Add excess to reverse debt if any
                    if (remaining.compareTo(BigDecimal.ZERO) < 0) {
                        pairDebts.put(keyReverse, pairDebts.getOrDefault(keyReverse, BigDecimal.ZERO).add(remaining.abs()));
                    }
                } else {
                    pairDebts.put(keyDirect, remaining);
                }
            } else if (pairDebts.containsKey(keyReverse)) {
                // If they settled in reverse, it adds to the reverse debt (they pre-paid or paid back)
                BigDecimal debt = pairDebts.get(keyReverse);
                pairDebts.put(keyReverse, debt.add(set.getAmount()));
            } else {
                // No direct debt existed, record as "reverse debt" (excess pre-payment)
                pairDebts.put(keyDirect, set.getAmount());
            }
        }

        // Net out direct A-B and B-A debts if both exist, e.g. A owes B 100, B owes A 30 -> A owes B 70
        List<String> keys = new ArrayList<>(pairDebts.keySet());
        Set<String> processedKeys = new HashSet<>();
        List<DebtResponse> debts = new ArrayList<>();

        for (String key : keys) {
            if (processedKeys.contains(key)) continue;

            String[] parts = key.split("-");
            Long fromId = Long.parseLong(parts[0]);
            Long toId = Long.parseLong(parts[1]);

            String reverseKey = toId + "-" + fromId;

            BigDecimal directAmt = pairDebts.getOrDefault(key, BigDecimal.ZERO);
            BigDecimal reverseAmt = pairDebts.getOrDefault(reverseKey, BigDecimal.ZERO);

            BigDecimal netAmt = directAmt.subtract(reverseAmt);
            processedKeys.add(key);
            processedKeys.add(reverseKey);

            if (netAmt.compareTo(BigDecimal.ZERO) > 0) {
                User fromUser = userMap.get(fromId);
                User toUser = userMap.get(toId);
                if (fromUser != null && toUser != null) {
                    debts.add(new DebtResponse(
                            new MemberResponse(fromUser.getId(), fromUser.getEmail()),
                            new MemberResponse(toUser.getId(), toUser.getEmail()),
                            netAmt.setScale(2, RoundingMode.HALF_EVEN)
                    ));
                }
            } else if (netAmt.compareTo(BigDecimal.ZERO) < 0) {
                User fromUser = userMap.get(toId);
                User toUser = userMap.get(fromId);
                if (fromUser != null && toUser != null) {
                    debts.add(new DebtResponse(
                            new MemberResponse(fromUser.getId(), fromUser.getEmail()),
                            new MemberResponse(toUser.getId(), toUser.getEmail()),
                            netAmt.abs().setScale(2, RoundingMode.HALF_EVEN)
                    ));
                }
            }
        }

        debts.sort(Comparator.comparing((DebtResponse d) -> d.getFromUser().getEmail())
                .thenComparing(d -> d.getToUser().getEmail()));

        return debts;
    }

    public List<DebtResponse> calculateOptimalTransactions(Collection<User> members, Map<Long, BigDecimal> netBalances) {
        Map<Long, User> userMap = members.stream().collect(Collectors.toMap(User::getId, u -> u));

        // Partiton members into creditors (> 0) and debtors (< 0)
        // Max heaps:
        // creditors sorted by balance descending
        // debtors sorted by absolute balance descending
        PriorityQueue<MemberBalanceNode> creditors = new PriorityQueue<>(
                (a, b) -> b.balance.compareTo(a.balance)
        );

        PriorityQueue<MemberBalanceNode> debtors = new PriorityQueue<>(
                (a, b) -> b.getAbsBalance().compareTo(a.getAbsBalance())
        );

        for (Map.Entry<Long, BigDecimal> entry : netBalances.entrySet()) {
            User user = userMap.get(entry.getKey());
            if (user == null) continue;

            BigDecimal bal = entry.getValue();
            // Scale and ignore values less than 1 cent to avoid floating residue
            bal = bal.setScale(2, RoundingMode.HALF_EVEN);

            if (bal.compareTo(BigDecimal.ZERO) > 0) {
                creditors.add(new MemberBalanceNode(user, bal));
            } else if (bal.compareTo(BigDecimal.ZERO) < 0) {
                debtors.add(new MemberBalanceNode(user, bal));
            }
        }

        List<DebtResponse> transactions = new ArrayList<>();

        while (!creditors.isEmpty() && !debtors.isEmpty()) {
            MemberBalanceNode c = creditors.poll();
            MemberBalanceNode d = debtors.poll();

            // settleAmount = min(c.amount, |d.amount|)
            BigDecimal dAbs = d.getAbsBalance();
            BigDecimal settleAmount = c.balance.min(dAbs);

            // Record transaction: d.user pays c.user settleAmount
            transactions.add(new DebtResponse(
                    new MemberResponse(d.user.getId(), d.user.getEmail()),
                    new MemberResponse(c.user.getId(), c.user.getEmail()),
                    settleAmount.setScale(2, RoundingMode.HALF_EVEN)
            ));

            c.balance = c.balance.subtract(settleAmount);
            d.balance = d.balance.add(settleAmount); // Move toward zero

            if (c.balance.compareTo(BigDecimal.ZERO) > 0) {
                creditors.add(c);
            }
            if (d.balance.compareTo(BigDecimal.ZERO) < 0) {
                debtors.add(d);
            }
        }

        return transactions;
    }
}
