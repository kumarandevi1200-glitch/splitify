package com.split.expensesplit.service;

import com.split.expensesplit.dto.DebtResponse;
import com.split.expensesplit.entity.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
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

        userY = new User();
        userY.setId(2L);
        userY.setEmail("y@example.com");

        userZ = new User();
        userZ.setId(3L);
        userZ.setEmail("z@example.com");
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
}
