package main

Operator :: enum {
    NONE,
    ADDITION,
    SUBTRACTION,
    MULTIPLICATION,
    DIVISION,
    MODULO,
}

Term :: distinct i64

SubExpression :: struct {
    lhs: union {
        Term,
        ^SubExpression
    },
    rhs: Maybe(union {
        Term,
        ^SubExpression
    }),
    op: Operator
}

Expression :: union {
    ^SubExpression,
    Term
}

Calculator :: struct {
    buffer: i64, // current value the user is entering in
    expr: Expression
}

evaluate_expression :: proc(expr: Expression) -> Term {
    result := Term(0)

    switch expression in expr {
        case Term:
            result = expression
        case ^SubExpression:
            result = evaluate_subexpression(expression)
    }

    return result
}

evaluate_subexpression :: proc(expr: ^SubExpression) -> Term {
    lhs := Term(0)
    switch l in expr.lhs {
    case Term:
        lhs = l
    case ^SubExpression:
        lhs = evaluate_subexpression(l)
    }

    // If there is nothing on the RHS, then just return the LHS term
    expr_rhs, rhs_ok := expr.rhs.?
    if !rhs_ok {
        return lhs
    }

    rhs := Term(0)
    switch r in expr_rhs {
    case Term:
        rhs = r
    case ^SubExpression:
        rhs = evaluate_subexpression(r)
    }

    result := Term(0)
    switch expr.op {
        case .NONE:
            panic("how'd this happen?")
        case .ADDITION:
            result = lhs + rhs
        case .SUBTRACTION:
            result = lhs - rhs
        case .MULTIPLICATION:
            result = lhs * rhs
        case .DIVISION:
            // TODO: Handle case where rhs may be 0
            result = lhs / rhs
        case .MODULO:
            // TODO: Handle case where rhs may be 0
            result = lhs % rhs
    }

    return result
}

set_op_expression :: proc(c: ^Calculator, op: Operator) {
    buf := Term(c.buffer)
    new_expr := new(SubExpression)

    switch &e in c.expr {
        case Term:
            new_expr.lhs = buf
            new_expr.rhs = nil
        case ^SubExpression:
            new_expr.lhs = e
            new_expr.rhs = buf
    }

    new_expr.op = op
    c.expr = new_expr
    c^.buffer = 0       // reset the buffer
}

create_term_from_buffer :: proc(c: ^Calculator) {
    new_term := Term(c.buffer)  // cast to term
    c^.expr = new_term          // copy the term
    c^.buffer = 0               // reset the buffer
}

equals :: proc(c: ^Calculator) {
    c^.expr = evaluate_expression(c.expr)
    c^.buffer = 0
}

