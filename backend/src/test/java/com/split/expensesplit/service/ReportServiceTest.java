package com.split.expensesplit.service;

import com.split.expensesplit.dto.DebtResponse;
import com.split.expensesplit.entity.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

public class ReportServiceTest {

    private ReportService reportService;
    private User userX;
    private User userY;
    private User userZ;

    @BeforeEach
    public void setUp() {
        reportService = new ReportService();

        userX = new User();
        userX.setId(1L);
        userX.setEmail("x@example.com");
        userX.setName("Alice");

        userY = new User();
        userY.setId(2L);
        userY.setEmail("y@example.com");
        userY.setName("Bob");

        userZ = new User();
        userZ.setId(3L);
        userZ.setEmail("z@example.com");
        userZ.setName("Charlie");
    }

    @Test
    public void testWorkedExample() {
        // Worked example: X owes Y ₹200, Y owes Z ₹300, Z owes X ₹200.
        // Net balances:
        // X = -200 + 200 = 0
        // Y = +200 - 300 = -100
        // Z = +300 - 200 = +100
        // Expected optimal: Y pays Z 100, and X does not appear.

        List<User> members = Arrays.asList(userX, userY, userZ);
        Map<Long, BigDecimal> netBalances = new HashMap<>();
        netBalances.put(userX.getId(), BigDecimal.valueOf(0));
        netBalances.put(userY.getId(), BigDecimal.valueOf(-100));
        netBalances.put(userZ.getId(), BigDecimal.valueOf(100));

        List<DebtResponse> optimal = reportService.calculateOptimalTransactions(members, netBalances);

        assertEquals(1, optimal.size(), "Should have exactly 1 transaction");
        DebtResponse tx = optimal.get(0);
        assertEquals(userY.getId(), tx.getFromUser().getId(), "Payer should be Y");
        assertEquals(userZ.getId(), tx.getToUser().getId(), "Recipient should be Z");
        assertEquals(new BigDecimal("100.00"), tx.getAmount(), "Amount should be 100");
    }

    @Test
    public void testFullySettledGroup() {
        // Balances: X = 0, Y = 0, Z = 0
        // Expected optimal: Empty list

        List<User> members = Arrays.asList(userX, userY, userZ);
        Map<Long, BigDecimal> netBalances = new HashMap<>();
        netBalances.put(userX.getId(), BigDecimal.valueOf(0));
        netBalances.put(userY.getId(), BigDecimal.valueOf(0));
        netBalances.put(userZ.getId(), BigDecimal.valueOf(0));

        List<DebtResponse> optimal = reportService.calculateOptimalTransactions(members, netBalances);

        assertTrue(optimal.isEmpty(), "Optimal transaction list should be empty");
    }

    @Test
    public void testTwoPersonGroup() {
        // Balances: X = -150, Y = 150
        // Expected optimal: X pays Y 150

        List<User> members = Arrays.asList(userX, userY);
        Map<Long, BigDecimal> netBalances = new HashMap<>();
        netBalances.put(userX.getId(), BigDecimal.valueOf(-150));
        netBalances.put(userY.getId(), BigDecimal.valueOf(150));

        List<DebtResponse> optimal = reportService.calculateOptimalTransactions(members, netBalances);

        assertEquals(1, optimal.size(), "Should have exactly 1 transaction");
        DebtResponse tx = optimal.get(0);
        assertEquals(userX.getId(), tx.getFromUser().getId(), "Payer should be X");
        assertEquals(userY.getId(), tx.getToUser().getId(), "Recipient should be Y");
        assertEquals(new BigDecimal("150.00"), tx.getAmount(), "Amount should be 150");
    }

    @Test
    public void testExcludedZeroBalanceMember() {
        // Balances: X = 0, Y = -250, Z = 250, W = 0
        // Expected optimal: Y pays Z 250, other members excluded

        User userW = new User();
        userW.setId(4L);
        userW.setEmail("w@example.com");
        userW.setName("David");

        List<User> members = Arrays.asList(userX, userY, userZ, userW);
        Map<Long, BigDecimal> netBalances = new HashMap<>();
        netBalances.put(userX.getId(), BigDecimal.valueOf(0));
        netBalances.put(userY.getId(), BigDecimal.valueOf(-250));
        netBalances.put(userZ.getId(), BigDecimal.valueOf(250));
        netBalances.put(userW.getId(), BigDecimal.valueOf(0));

        List<DebtResponse> optimal = reportService.calculateOptimalTransactions(members, netBalances);

        assertEquals(1, optimal.size(), "Should have exactly 1 transaction");
        DebtResponse tx = optimal.get(0);
        assertEquals(userY.getId(), tx.getFromUser().getId(), "Payer should be Y");
        assertEquals(userZ.getId(), tx.getToUser().getId(), "Recipient should be Z");
        assertEquals(new BigDecimal("250.00"), tx.getAmount(), "Amount should be 250");
    }

    @Test
    public void testCalculateNetBalancesWithSettlements() {
        List<User> members = Arrays.asList(userX, userY, userZ);

        com.split.expensesplit.entity.Expense expense = new com.split.expensesplit.entity.Expense();
        expense.setPayer(userX);
        expense.setAmount(new BigDecimal("300.00"));
        
        com.split.expensesplit.entity.ExpenseShare shareX = new com.split.expensesplit.entity.ExpenseShare(expense, userX, new BigDecimal("100.00"), null, null);
        com.split.expensesplit.entity.ExpenseShare shareY = new com.split.expensesplit.entity.ExpenseShare(expense, userY, new BigDecimal("100.00"), null, null);
        com.split.expensesplit.entity.ExpenseShare shareZ = new com.split.expensesplit.entity.ExpenseShare(expense, userZ, new BigDecimal("100.00"), null, null);
        expense.setShares(Arrays.asList(shareX, shareY, shareZ));

        com.split.expensesplit.entity.Settlement settlement = new com.split.expensesplit.entity.Settlement();
        settlement.setPaidBy(userY);
        settlement.setPaidTo(userX);
        settlement.setAmount(new BigDecimal("100.00"));

        Map<Long, BigDecimal> netBalances = reportService.calculateNetBalances(
                members,
                Collections.singletonList(expense),
                Collections.singletonList(settlement)
        );

        assertEquals(new BigDecimal("100.00"), netBalances.get(userX.getId()).setScale(2, RoundingMode.HALF_EVEN), "X balance should be +100");
        assertEquals(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_EVEN), netBalances.get(userY.getId()).setScale(2, RoundingMode.HALF_EVEN), "Y balance should be 0");
        assertEquals(new BigDecimal("-100.00"), netBalances.get(userZ.getId()).setScale(2, RoundingMode.HALF_EVEN), "Z balance should be -100");
    }

    @Test
    public void testCalculateDirectDebtsWithSettlements() {
        List<User> members = Arrays.asList(userX, userY, userZ);

        com.split.expensesplit.entity.Expense expense = new com.split.expensesplit.entity.Expense();
        expense.setPayer(userX);
        expense.setAmount(new BigDecimal("300.00"));
        
        com.split.expensesplit.entity.ExpenseShare shareX = new com.split.expensesplit.entity.ExpenseShare(expense, userX, new BigDecimal("100.00"), null, null);
        com.split.expensesplit.entity.ExpenseShare shareY = new com.split.expensesplit.entity.ExpenseShare(expense, userY, new BigDecimal("100.00"), null, null);
        com.split.expensesplit.entity.ExpenseShare shareZ = new com.split.expensesplit.entity.ExpenseShare(expense, userZ, new BigDecimal("100.00"), null, null);
        expense.setShares(Arrays.asList(shareX, shareY, shareZ));

        // Y pays Z 50 (pre-payment, Z now owes Y 50)
        com.split.expensesplit.entity.Settlement set1 = new com.split.expensesplit.entity.Settlement();
        set1.setPaidBy(userY);
        set1.setPaidTo(userZ);
        set1.setAmount(new BigDecimal("50.00"));

        // Y pays X 60 (Y owed X 100, now Y owes X 40)
        com.split.expensesplit.entity.Settlement set2 = new com.split.expensesplit.entity.Settlement();
        set2.setPaidBy(userY);
        set2.setPaidTo(userX);
        set2.setAmount(new BigDecimal("60.00"));

        List<DebtResponse> directDebts = reportService.calculateDirectDebts(
                members,
                Collections.singletonList(expense),
                Arrays.asList(set1, set2)
        );

        // Expected direct debts:
        // 1. Y owes X 40.00
        // 2. Z owes Y 50.00
        // 3. Z owes X 100.00
        assertEquals(3, directDebts.size(), "Should have exactly 3 direct debts");
        
        // They are sorted by fromUser.email then toUser.email
        // Members: X (1L, x@example.com), Y (2L, y@example.com), Z (3L, z@example.com)
        // Debt 1: from Y (y@example.com) to X (x@example.com) -> amount 40
        // Debt 2: from Z (z@example.com) to X (x@example.com) -> amount 100
        // Debt 3: from Z (z@example.com) to Y (y@example.com) -> amount 50
        
        DebtResponse debt1 = directDebts.get(0);
        assertEquals(userY.getId(), debt1.getFromUser().getId());
        assertEquals(userX.getId(), debt1.getToUser().getId());
        assertEquals(new BigDecimal("40.00"), debt1.getAmount());

        DebtResponse debt2 = directDebts.get(1);
        assertEquals(userZ.getId(), debt2.getFromUser().getId());
        assertEquals(userX.getId(), debt2.getToUser().getId());
        assertEquals(new BigDecimal("100.00"), debt2.getAmount());

        DebtResponse debt3 = directDebts.get(2);
        assertEquals(userZ.getId(), debt3.getFromUser().getId());
        assertEquals(userY.getId(), debt3.getToUser().getId());
        assertEquals(new BigDecimal("50.00"), debt3.getAmount());
    }
}
