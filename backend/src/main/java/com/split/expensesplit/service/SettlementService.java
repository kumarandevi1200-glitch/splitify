package com.split.expensesplit.service;

import com.split.expensesplit.dto.MemberResponse;
import com.split.expensesplit.dto.SettlementCreateRequest;
import com.split.expensesplit.dto.SettlementResponse;
import com.split.expensesplit.entity.Group;
import com.split.expensesplit.entity.Settlement;
import com.split.expensesplit.entity.User;
import com.split.expensesplit.exception.CustomException;
import com.split.expensesplit.repository.SettlementRepository;
import com.split.expensesplit.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class SettlementService {

    @Autowired
    private SettlementRepository settlementRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private GroupService groupService;

    @Transactional
    public SettlementResponse recordSettlement(Long groupId, SettlementCreateRequest request, String email) {
        // 1. Verify group exists and caller is member
        Group group = groupService.getGroupAndVerifyMembership(groupId, email);

        // 2. Fetch paidBy (caller) and paidTo (recipient)
        User paidBy = userRepository.findByEmail(email)
                .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "Payer not found", HttpStatus.BAD_REQUEST));
        
        User paidTo = userRepository.findById(request.getPaidToId())
                .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "Recipient not found", HttpStatus.BAD_REQUEST));

        // 3. Verify recipient is a member of the group
        if (!group.getMembers().contains(paidTo)) {
            throw new CustomException("RECIPIENT_NOT_MEMBER", "Recipient is not a member of the group", HttpStatus.BAD_REQUEST);
        }

        // 4. Verify amount is > 0
        if (request.getAmount() == null || request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new CustomException("INVALID_AMOUNT", "Amount must be greater than 0", HttpStatus.BAD_REQUEST);
        }

        // 5. Create Settlement record
        Settlement settlement = new Settlement();
        settlement.setGroup(group);
        settlement.setPaidBy(paidBy);
        settlement.setPaidTo(paidTo);
        settlement.setAmount(request.getAmount().setScale(2, RoundingMode.HALF_EVEN));
        settlement.setNote(request.getNote());
        settlement.setSettlementDate(LocalDateTime.now());

        Settlement savedSettlement = settlementRepository.save(settlement);
        return mapToSettlementResponse(savedSettlement);
    }

    @Transactional(readOnly = true)
    public List<SettlementResponse> listGroupSettlements(Long groupId, String email) {
        groupService.getGroupAndVerifyMembership(groupId, email);
        List<Settlement> settlements = settlementRepository.findByGroupIdOrderBySettlementDateDesc(groupId);
        return settlements.stream().map(this::mapToSettlementResponse).collect(Collectors.toList());
    }

    private SettlementResponse mapToSettlementResponse(Settlement settlement) {
        MemberResponse paidBy = new MemberResponse(settlement.getPaidBy().getId(), settlement.getPaidBy().getEmail());
        MemberResponse paidTo = new MemberResponse(settlement.getPaidTo().getId(), settlement.getPaidTo().getEmail());

        return new SettlementResponse(
                settlement.getId(),
                paidBy,
                paidTo,
                settlement.getAmount(),
                settlement.getNote(),
                settlement.getSettlementDate()
        );
    }
}
