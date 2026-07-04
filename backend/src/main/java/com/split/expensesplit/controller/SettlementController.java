package com.split.expensesplit.controller;

import com.split.expensesplit.dto.SettlementCreateRequest;
import com.split.expensesplit.dto.SettlementResponse;
import com.split.expensesplit.service.SettlementService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;

@RestController
@RequestMapping("/api/groups/{groupId}/settlements")
public class SettlementController {

    @Autowired
    private SettlementService settlementService;

    @PostMapping
    public ResponseEntity<SettlementResponse> recordSettlement(
            @PathVariable("groupId") Long groupId,
            @Valid @RequestBody SettlementCreateRequest request,
            Principal principal) {
        return ResponseEntity.ok(settlementService.recordSettlement(groupId, request, principal.getName()));
    }

    @PutMapping("/{settlementId}")
    public ResponseEntity<SettlementResponse> updateSettlement(
            @PathVariable("groupId") Long groupId,
            @PathVariable("settlementId") Long settlementId,
            @Valid @RequestBody SettlementCreateRequest request,
            Principal principal) {
        return ResponseEntity.ok(settlementService.updateSettlement(groupId, settlementId, request, principal.getName()));
    }

    @DeleteMapping("/{settlementId}")
    public ResponseEntity<Void> deleteSettlement(
            @PathVariable("groupId") Long groupId,
            @PathVariable("settlementId") Long settlementId,
            Principal principal) {
        settlementService.deleteSettlement(groupId, settlementId, principal.getName());
        return ResponseEntity.noContent().build();
    }

    @GetMapping
    public ResponseEntity<List<SettlementResponse>> listGroupSettlements(
            @PathVariable("groupId") Long groupId,
            Principal principal) {
        return ResponseEntity.ok(settlementService.listGroupSettlements(groupId, principal.getName()));
    }
}
