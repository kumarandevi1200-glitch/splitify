package com.split.expensesplit.controller;

import com.split.expensesplit.dto.ExpenseCreateRequest;
import com.split.expensesplit.dto.ExpenseResponse;
import com.split.expensesplit.service.ExpenseService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;

@RestController
@RequestMapping("/api/groups/{groupId}/expenses")
public class ExpenseController {

    @Autowired
    private ExpenseService expenseService;

    @PostMapping
    public ResponseEntity<ExpenseResponse> createExpense(
            @PathVariable("groupId") Long groupId,
            @Valid @RequestBody ExpenseCreateRequest request,
            Principal principal) {
        return ResponseEntity.ok(expenseService.createExpense(groupId, request, principal.getName()));
    }

    @PutMapping("/{expenseId}")
    public ResponseEntity<ExpenseResponse> updateExpense(
            @PathVariable("groupId") Long groupId,
            @PathVariable("expenseId") Long expenseId,
            @Valid @RequestBody ExpenseCreateRequest request,
            Principal principal) {
        return ResponseEntity.ok(expenseService.updateExpense(groupId, expenseId, request, principal.getName()));
    }

    @DeleteMapping("/{expenseId}")
    public ResponseEntity<Void> deleteExpense(
            @PathVariable("groupId") Long groupId,
            @PathVariable("expenseId") Long expenseId,
            Principal principal) {
        expenseService.deleteExpense(groupId, expenseId, principal.getName());
        return ResponseEntity.noContent().build();
    }

    @GetMapping
    public ResponseEntity<List<ExpenseResponse>> listGroupExpenses(
            @PathVariable("groupId") Long groupId,
            Principal principal) {
        return ResponseEntity.ok(expenseService.listGroupExpenses(groupId, principal.getName()));
    }
}
