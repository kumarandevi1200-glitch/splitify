package com.split.expensesplit.service;

import com.split.expensesplit.dto.*;
import com.split.expensesplit.entity.Expense;
import com.split.expensesplit.entity.ExpenseShare;
import com.split.expensesplit.entity.Group;
import com.split.expensesplit.entity.User;
import com.split.expensesplit.exception.CustomException;
import com.split.expensesplit.repository.ExpenseRepository;
import com.split.expensesplit.repository.GroupRepository;
import com.split.expensesplit.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ExpenseService {

    @Autowired
    private ExpenseRepository expenseRepository;

    @Autowired
    private GroupRepository groupRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private GroupService groupService;

    @Transactional
    public ExpenseResponse createExpense(Long groupId, ExpenseCreateRequest request, String email) {
        // 1. Verify group and caller membership
        Group group = groupService.getGroupAndVerifyMembership(groupId, email);

        // 2. Verify amount is > 0
        if (request.getAmount() == null || request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new CustomException("INVALID_AMOUNT", "Amount must be greater than 0", HttpStatus.BAD_REQUEST);
        }

        // 3. Verify payer is a group member
        User payer = userRepository.findById(request.getPayerId())
                .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "Payer not found", HttpStatus.BAD_REQUEST));
        
        if (!group.getMembers().contains(payer)) {
            throw new CustomException("PAYER_NOT_MEMBER", "Payer is not a member of the group", HttpStatus.BAD_REQUEST);
        }

        // 4. Verify all participants are group members
        List<User> participants = new ArrayList<>();
        for (ShareRequest shareReq : request.getShares()) {
            User p = userRepository.findById(shareReq.getUserId())
                    .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "Participant not found: " + shareReq.getUserId(), HttpStatus.BAD_REQUEST));
            if (!group.getMembers().contains(p)) {
                throw new CustomException("PARTICIPANT_NOT_MEMBER", "Participant " + p.getEmail() + " is not a member of the group", HttpStatus.BAD_REQUEST);
            }
            participants.add(p);
        }

        // 5. Initialize Expense Entity
        Expense expense = new Expense();
        expense.setGroup(group);
        expense.setPayer(payer);
        expense.setAmount(request.getAmount().setScale(2, RoundingMode.HALF_EVEN));
        expense.setDescription(request.getDescription());
        expense.setSplitType(request.getSplitType().toUpperCase());
        expense.setCategory(request.getCategory());
        expense.setExpenseDate(LocalDateTime.now());

        // 6. Split Calculations
        List<ExpenseShare> calculatedShares = calculateShares(expense, request.getShares(), participants);
        expense.setShares(calculatedShares);

        Expense savedExpense = expenseRepository.save(expense);
        return mapToExpenseResponse(savedExpense);
    }

    @Transactional
    public ExpenseResponse updateExpense(Long groupId, Long expenseId, ExpenseCreateRequest request, String email) {
        groupService.getGroupAndVerifyMembership(groupId, email);

        Expense expense = expenseRepository.findById(expenseId)
                .orElseThrow(() -> new CustomException("EXPENSE_NOT_FOUND", "Expense not found", HttpStatus.NOT_FOUND));

        if (!expense.getGroup().getId().equals(groupId)) {
            throw new CustomException("EXPENSE_NOT_IN_GROUP", "Expense does not belong to the specified group", HttpStatus.BAD_REQUEST);
        }

        if (expense.isDeleted()) {
            throw new CustomException("EXPENSE_DELETED", "Cannot update a soft-deleted expense", HttpStatus.BAD_REQUEST);
        }

        // Verify version matches DTO to prevent concurrent edits
        // Spring JPA @Version handles actual locking, but checking inputs is good practice.

        if (request.getAmount() == null || request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new CustomException("INVALID_AMOUNT", "Amount must be greater than 0", HttpStatus.BAD_REQUEST);
        }

        User payer = userRepository.findById(request.getPayerId())
                .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "Payer not found", HttpStatus.BAD_REQUEST));
        if (!expense.getGroup().getMembers().contains(payer)) {
            throw new CustomException("PAYER_NOT_MEMBER", "Payer is not a member of the group", HttpStatus.BAD_REQUEST);
        }

        List<User> participants = new ArrayList<>();
        for (ShareRequest shareReq : request.getShares()) {
            User p = userRepository.findById(shareReq.getUserId())
                    .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "Participant not found: " + shareReq.getUserId(), HttpStatus.BAD_REQUEST));
            if (!expense.getGroup().getMembers().contains(p)) {
                throw new CustomException("PARTICIPANT_NOT_MEMBER", "Participant " + p.getEmail() + " is not a member of the group", HttpStatus.BAD_REQUEST);
            }
            participants.add(p);
        }

        expense.setPayer(payer);
        expense.setAmount(request.getAmount().setScale(2, RoundingMode.HALF_EVEN));
        expense.setDescription(request.getDescription());
        expense.setSplitType(request.getSplitType().toUpperCase());
        expense.setCategory(request.getCategory());

        // Recalculate shares
        expense.getShares().clear();
        List<ExpenseShare> calculatedShares = calculateShares(expense, request.getShares(), participants);
        expense.getShares().addAll(calculatedShares);

        Expense savedExpense = expenseRepository.save(expense);
        return mapToExpenseResponse(savedExpense);
    }

    @Transactional
    public void deleteExpense(Long groupId, Long expenseId, String email) {
        groupService.getGroupAndVerifyMembership(groupId, email);

        Expense expense = expenseRepository.findById(expenseId)
                .orElseThrow(() -> new CustomException("EXPENSE_NOT_FOUND", "Expense not found", HttpStatus.NOT_FOUND));

        if (!expense.getGroup().getId().equals(groupId)) {
            throw new CustomException("EXPENSE_NOT_IN_GROUP", "Expense does not belong to the specified group", HttpStatus.BAD_REQUEST);
        }

        expense.setDeleted(true);
        expenseRepository.save(expense);
    }

    @Transactional(readOnly = true)
    public List<ExpenseResponse> listGroupExpenses(Long groupId, String email) {
        groupService.getGroupAndVerifyMembership(groupId, email);
        List<Expense> expenses = expenseRepository.findByGroupIdAndIsDeletedFalseOrderByExpenseDateDesc(groupId);
        return expenses.stream().map(this::mapToExpenseResponse).collect(Collectors.toList());
    }

    private List<ExpenseShare> calculateShares(Expense expense, List<ShareRequest> shareRequests, List<User> participants) {
        BigDecimal totalAmount = expense.getAmount();
        String splitType = expense.getSplitType();
        int n = participants.size();

        List<ExpenseShare> sharesList = new ArrayList<>();
        BigDecimal sumCalculatedShares = BigDecimal.ZERO;

        if ("EQUAL".equals(splitType)) {
            // Divide amount by participants count and round down
            BigDecimal equalShare = totalAmount.divide(BigDecimal.valueOf(n), 2, RoundingMode.DOWN);
            
            for (int i = 0; i < n; i++) {
                User user = participants.get(i);
                sharesList.add(new ExpenseShare(expense, user, equalShare, null, null));
                sumCalculatedShares = sumCalculatedShares.add(equalShare);
            }
        } 
        else if ("EXACT".equals(splitType)) {
            BigDecimal requestSum = BigDecimal.ZERO;
            for (int i = 0; i < n; i++) {
                ShareRequest sr = shareRequests.get(i);
                if (sr.getAmount() == null || sr.getAmount().compareTo(BigDecimal.ZERO) < 0) {
                    throw new CustomException("INVALID_SPLIT_VALUE", "Share amount must be non-negative", HttpStatus.BAD_REQUEST);
                }
                BigDecimal val = sr.getAmount().setScale(2, RoundingMode.HALF_EVEN);
                requestSum = requestSum.add(val);
                sharesList.add(new ExpenseShare(expense, participants.get(i), val, null, null));
            }
            if (requestSum.compareTo(totalAmount) != 0) {
                throw new CustomException("SPLIT_MISMATCH", "Exact shares sum (" + requestSum + ") does not match expense amount (" + totalAmount + ")", HttpStatus.BAD_REQUEST);
            }
            sumCalculatedShares = totalAmount; // Sum is exact
        } 
        else if ("PERCENTAGE".equals(splitType)) {
            BigDecimal pctSum = BigDecimal.ZERO;
            for (int i = 0; i < n; i++) {
                ShareRequest sr = shareRequests.get(i);
                if (sr.getPercentage() == null || sr.getPercentage().compareTo(BigDecimal.ZERO) < 0) {
                    throw new CustomException("INVALID_SPLIT_VALUE", "Percentage must be non-negative", HttpStatus.BAD_REQUEST);
                }
                pctSum = pctSum.add(sr.getPercentage());
                
                // Calculate portion and round down
                BigDecimal shareAmt = totalAmount.multiply(sr.getPercentage())
                        .divide(BigDecimal.valueOf(100), 2, RoundingMode.DOWN);
                
                sharesList.add(new ExpenseShare(expense, participants.get(i), shareAmt, sr.getPercentage(), null));
                sumCalculatedShares = sumCalculatedShares.add(shareAmt);
            }
            // Percentage sum must be exactly 100%
            if (pctSum.setScale(2, RoundingMode.HALF_EVEN).compareTo(BigDecimal.valueOf(100).setScale(2, RoundingMode.HALF_EVEN)) != 0) {
                throw new CustomException("SPLIT_MISMATCH", "Percentages must sum to exactly 100%", HttpStatus.BAD_REQUEST);
            }
        } 
        else if ("SHARES".equals(splitType)) {
            BigDecimal totalShares = BigDecimal.ZERO;
            for (ShareRequest sr : shareRequests) {
                if (sr.getShares() == null || sr.getShares().compareTo(BigDecimal.ZERO) <= 0) {
                    throw new CustomException("INVALID_SPLIT_VALUE", "Shares weight must be greater than 0", HttpStatus.BAD_REQUEST);
                }
                totalShares = totalShares.add(sr.getShares());
            }

            for (int i = 0; i < n; i++) {
                ShareRequest sr = shareRequests.get(i);
                // shareAmt = amount * (participantShares / totalShares)
                BigDecimal shareAmt = totalAmount.multiply(sr.getShares())
                        .divide(totalShares, 2, RoundingMode.DOWN);

                sharesList.add(new ExpenseShare(expense, participants.get(i), shareAmt, null, sr.getShares()));
                sumCalculatedShares = sumCalculatedShares.add(shareAmt);
            }
        } 
        else {
            throw new CustomException("INVALID_SPLIT_TYPE", "Invalid split type: " + splitType, HttpStatus.BAD_REQUEST);
        }

        // Adjust leftover cents and assign to the first participant in list deterministically
        BigDecimal leftover = totalAmount.subtract(sumCalculatedShares);
        if (leftover.compareTo(BigDecimal.ZERO) != 0 && !sharesList.isEmpty()) {
            ExpenseShare firstShare = sharesList.getFirst();
            firstShare.setShareAmount(firstShare.getShareAmount().add(leftover));
        }

        return sharesList;
    }

    public ExpenseResponse mapToExpenseResponse(Expense expense) {
        MemberResponse payer = new MemberResponse(expense.getPayer().getId(), expense.getPayer().getEmail());
        
        List<ExpenseShareResponse> shares = expense.getShares().stream()
                .map(s -> new ExpenseShareResponse(
                        s.getUser().getId(),
                        s.getUser().getEmail(),
                        s.getShareAmount(),
                        s.getPercentage(),
                        s.getShares()
                ))
                .collect(Collectors.toList());

        return new ExpenseResponse(
                expense.getId(),
                expense.getAmount(),
                expense.getDescription(),
                expense.getSplitType(),
                payer,
                expense.getCategory(),
                expense.getExpenseDate(),
                expense.isDeleted(),
                expense.getVersion(),
                shares
        );
    }
}
