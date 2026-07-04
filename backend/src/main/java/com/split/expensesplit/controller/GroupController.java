package com.split.expensesplit.controller;

import com.split.expensesplit.dto.*;
import com.split.expensesplit.service.GroupService;
import com.split.expensesplit.service.ReportService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;

@RestController
@RequestMapping("/api/groups")
public class GroupController {

    @Autowired
    private GroupService groupService;

    @Autowired
    private ReportService reportService;

    @PostMapping
    public ResponseEntity<GroupResponse> createGroup(
            @Valid @RequestBody GroupCreateRequest request,
            Principal principal) {
        return ResponseEntity.ok(groupService.createGroup(request, principal.getName()));
    }

    @GetMapping
    public ResponseEntity<List<GroupResponse>> listUserGroups(Principal principal) {
        return ResponseEntity.ok(groupService.listUserGroups(principal.getName()));
    }

    @PostMapping("/{id}/invite-code")
    public ResponseEntity<InviteCodeResponse> generateInviteCode(
            @PathVariable("id") Long groupId,
            @RequestParam(name = "validityHours", required = false) Long validityHours,
            @RequestParam(name = "maxUses", required = false) Integer maxUses,
            Principal principal) {
        return ResponseEntity.ok(groupService.generateInviteCode(groupId, principal.getName(), validityHours, maxUses));
    }

    @PostMapping("/join")
    public ResponseEntity<GroupResponse> joinGroup(
            @Valid @RequestBody JoinGroupRequest request,
            Principal principal) {
        return ResponseEntity.ok(groupService.joinGroup(request.getCode(), principal.getName()));
    }

    @GetMapping("/{id}/members")
    public ResponseEntity<List<MemberResponse>> listGroupMembers(
            @PathVariable("id") Long groupId,
            Principal principal) {
        return ResponseEntity.ok(groupService.listGroupMembers(groupId, principal.getName()));
    }

    @GetMapping("/{id}/report")
    public ResponseEntity<ReportResponse> generateReport(
            @PathVariable("id") Long groupId,
            Principal principal) {
        return ResponseEntity.ok(reportService.generateReport(groupId, principal.getName()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteGroup(
            @PathVariable("id") Long groupId,
            Principal principal) {
        groupService.deleteGroup(groupId, principal.getName());
        return ResponseEntity.noContent().build();
    }
}
