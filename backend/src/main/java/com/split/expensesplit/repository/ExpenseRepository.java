package com.split.expensesplit.repository;

import com.split.expensesplit.entity.Expense;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExpenseRepository extends JpaRepository<Expense, Long> {
    List<Expense> findByGroupIdAndIsDeletedFalseOrderByExpenseDateDesc(Long groupId);
}
