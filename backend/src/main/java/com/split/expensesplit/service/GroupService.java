package com.split.expensesplit.service;

import com.split.expensesplit.dto.GroupCreateRequest;
import com.split.expensesplit.dto.GroupResponse;
import com.split.expensesplit.dto.InviteCodeResponse;
import com.split.expensesplit.dto.MemberResponse;
import com.split.expensesplit.entity.Group;
import com.split.expensesplit.entity.GroupInviteCode;
import com.split.expensesplit.entity.User;
import com.split.expensesplit.exception.CustomException;
import com.split.expensesplit.repository.GroupInviteCodeRepository;
import com.split.expensesplit.repository.GroupRepository;
import com.split.expensesplit.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class GroupService {

    // Unambiguous charset: excludes O, 0, I, 1, l
    private static final String CHARSET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    private static final SecureRandom RANDOM = new SecureRandom();

    @Autowired
    private GroupRepository groupRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private GroupInviteCodeRepository groupInviteCodeRepository;

    private String generateUniqueCode() {
        int attempts = 0;
        while (attempts < 10) {
            int length = 6 + RANDOM.nextInt(3); // 6 to 8 chars
            StringBuilder sb = new StringBuilder(length);
            for (int i = 0; i < length; i++) {
                sb.append(CHARSET.charAt(RANDOM.nextInt(CHARSET.length())));
            }
            String code = sb.toString();
            if (!groupInviteCodeRepository.existsByCode(code)) {
                return code;
            }
            attempts++;
        }
        throw new CustomException("SERVER_ERROR", "Failed to generate unique invite code", HttpStatus.INTERNAL_SERVER_ERROR);
    }

    @Transactional
    public GroupResponse createGroup(GroupCreateRequest request, String creatorEmail) {
        User creator = userRepository.findByEmail(creatorEmail)
                .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "Creator not found", HttpStatus.NOT_FOUND));

        Group group = new Group(request.getName(), request.getCurrency());
        group.getMembers().add(creator);
        Group savedGroup = groupRepository.save(group);

        return mapToGroupResponse(savedGroup);
    }

    @Transactional(readOnly = true)
    public List<GroupResponse> listUserGroups(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "User not found", HttpStatus.NOT_FOUND));

        List<Group> groups = groupRepository.findByMembersId(user.getId());
        return groups.stream().map(this::mapToGroupResponse).collect(Collectors.toList());
    }

    @Transactional
    public InviteCodeResponse generateInviteCode(Long groupId, String email, Long validityHours, Integer maxUses) {
        Group group = getGroupAndVerifyMembership(groupId, email);

        String code = generateUniqueCode();
        LocalDateTime expiresAt = (validityHours != null) ? LocalDateTime.now().plusHours(validityHours) : null;

        GroupInviteCode inviteCode = new GroupInviteCode(group, code, expiresAt, maxUses);
        GroupInviteCode savedCode = groupInviteCodeRepository.save(inviteCode);

        return new InviteCodeResponse(
                savedCode.getCode(),
                savedCode.getExpiresAt(),
                savedCode.getMaxUses(),
                savedCode.getUsesCount()
        );
    }

    @Transactional
    public GroupResponse joinGroup(String code, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "User not found", HttpStatus.NOT_FOUND));

        GroupInviteCode inviteCode = groupInviteCodeRepository.findByCode(code)
                .orElseThrow(() -> new CustomException("INVITE_CODE_INVALID", "Invalid invite code", HttpStatus.BAD_REQUEST));

        if (inviteCode.isExpired()) {
            throw new CustomException("INVITE_CODE_EXPIRED", "This invite code has expired", HttpStatus.BAD_REQUEST);
        }

        if (inviteCode.isExhausted()) {
            throw new CustomException("INVITE_CODE_EXHAUSTED", "This invite code usage limit has been reached", HttpStatus.BAD_REQUEST);
        }

        Group group = inviteCode.getGroup();

        if (group.getMembers().contains(user)) {
            throw new CustomException("GROUP_ALREADY_MEMBER", "You are already a member of this group", HttpStatus.BAD_REQUEST);
        }

        group.getMembers().add(user);
        inviteCode.setUsesCount(inviteCode.getUsesCount() + 1);

        groupRepository.save(group);
        groupInviteCodeRepository.save(inviteCode);

        return mapToGroupResponse(group);
    }

    @Transactional(readOnly = true)
    public List<MemberResponse> listGroupMembers(Long groupId, String email) {
        Group group = getGroupAndVerifyMembership(groupId, email);
        return group.getMembers().stream()
                .map(m -> new MemberResponse(m.getId(), m.getDisplayName()))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public Group getGroupAndVerifyMembership(Long groupId, String email) {
        Group group = groupRepository.findById(groupId)
                .orElseThrow(() -> new CustomException("GROUP_NOT_FOUND", "Group not found", HttpStatus.NOT_FOUND));

        boolean isMember = group.getMembers().stream()
                .anyMatch(member -> member.getEmail().equals(email));

        if (!isMember) {
            throw new CustomException("GROUP_NOT_MEMBER", "You are not a member of this group", HttpStatus.FORBIDDEN);
        }

        return group;
    }

    @Transactional
    public void deleteGroup(Long groupId, String email) {
        Group group = getGroupAndVerifyMembership(groupId, email);
        groupRepository.delete(group);
    }

    private GroupResponse mapToGroupResponse(Group group) {
        List<MemberResponse> members = group.getMembers().stream()
                .map(m -> new MemberResponse(m.getId(), m.getDisplayName()))
                .collect(Collectors.toList());

        return new GroupResponse(
                group.getId(),
                group.getName(),
                group.getCurrency(),
                members,
                group.getCreatedAt()
        );
    }
}
