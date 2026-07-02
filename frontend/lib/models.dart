
class User {
  final int id;
  final String email;

  User({required this.id, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
    );
  }
}

class Group {
  final int id;
  final String name;
  final String currency;
  final List<User> members;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.currency,
    required this.members,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    var membersList = json['members'] as List? ?? [];
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      currency: json['currency'] as String,
      members: membersList.map((m) => User.fromJson(m)).toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ExpenseShare {
  final int userId;
  final String email;
  final double shareAmount;
  final double? percentage;
  final double? shares;

  ExpenseShare({
    required this.userId,
    required this.email,
    required this.shareAmount,
    this.percentage,
    this.shares,
  });

  factory ExpenseShare.fromJson(Map<String, dynamic> json) {
    return ExpenseShare(
      userId: json['userId'] as int,
      email: json['email'] as String,
      shareAmount: (json['shareAmount'] as num).toDouble(),
      percentage: json['percentage'] != null ? (json['percentage'] as num).toDouble() : null,
      shares: json['shares'] != null ? (json['shares'] as num).toDouble() : null,
    );
  }
}

class Expense {
  final int id;
  final double amount;
  final String description;
  final String splitType;
  final User payer;
  final String category;
  final DateTime expenseDate;
  final bool isDeleted;
  final int version;
  final List<ExpenseShare> shares;

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.splitType,
    required this.payer,
    required this.category,
    required this.expenseDate,
    required this.isDeleted,
    required this.version,
    required this.shares,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    var sharesList = json['shares'] as List? ?? [];
    return Expense(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      splitType: json['splitType'] as String,
      payer: User.fromJson(json['payer']),
      category: json['category'] as String? ?? 'General',
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      isDeleted: json['deleted'] as bool? ?? false,
      version: json['version'] as int? ?? 0,
      shares: sharesList.map((s) => ExpenseShare.fromJson(s)).toList(),
    );
  }
}

class Settlement {
  final int id;
  final User paidBy;
  final User paidTo;
  final double amount;
  final String? note;
  final DateTime settlementDate;

  Settlement({
    required this.id,
    required this.paidBy,
    required this.paidTo,
    required this.amount,
    this.note,
    required this.settlementDate,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as int,
      paidBy: User.fromJson(json['paidBy']),
      paidTo: User.fromJson(json['paidTo']),
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String?,
      settlementDate: DateTime.parse(json['settlementDate'] as String),
    );
  }
}

class MemberBalance {
  final int userId;
  final String email;
  final double balance;

  MemberBalance({
    required this.userId,
    required this.email,
    required this.balance,
  });

  factory MemberBalance.fromJson(Map<String, dynamic> json) {
    return MemberBalance(
      userId: json['userId'] as int,
      email: json['email'] as String,
      balance: (json['balance'] as num).toDouble(),
    );
  }
}

class Debt {
  final User fromUser;
  final User toUser;
  final double amount;

  Debt({
    required this.fromUser,
    required this.toUser,
    required this.amount,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      fromUser: User.fromJson(json['fromUser']),
      toUser: User.fromJson(json['toUser']),
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class CategoryBreakdown {
  final String category;
  final double amount;

  CategoryBreakdown({required this.category, required this.amount});

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class DailySpend {
  final String date;
  final double amount;

  DailySpend({required this.date, required this.amount});

  factory DailySpend.fromJson(Map<String, dynamic> json) {
    return DailySpend(
      date: json['date'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class Report {
  final double totalSpend;
  final List<MemberBalance> balances;
  final List<Debt> directDebts;
  final List<Debt> optimalTransactions;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<DailySpend> dailySpend;

  Report({
    required this.totalSpend,
    required this.balances,
    required this.directDebts,
    required this.optimalTransactions,
    required this.categoryBreakdown,
    required this.dailySpend,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    var balancesList = json['balances'] as List? ?? [];
    var directList = json['directDebts'] as List? ?? [];
    var optimalList = json['optimalTransactions'] as List? ?? [];
    var categoryList = json['categoryBreakdown'] as List? ?? [];
    var dailyList = json['dailySpend'] as List? ?? [];

    return Report(
      totalSpend: (json['totalSpend'] as num).toDouble(),
      balances: balancesList.map((b) => MemberBalance.fromJson(b)).toList(),
      directDebts: directList.map((d) => Debt.fromJson(d)).toList(),
      optimalTransactions: optimalList.map((d) => Debt.fromJson(d)).toList(),
      categoryBreakdown: categoryList.map((c) => CategoryBreakdown.fromJson(c)).toList(),
      dailySpend: dailyList.map((d) => DailySpend.fromJson(d)).toList(),
    );
  }
}
