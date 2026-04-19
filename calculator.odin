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
    lhs: Maybe(union {
        Term,
        ^SubExpression
    }),
    rhs: Maybe(union {
        Term,
        ^SubExpression
    }),
    op: Operator
}

Expression :: union {
    SubExpression,
    Term
}

Calculator :: struct {
    buffer: i64, // current value the user is entering in
    expr: Expression
}

evaluate_expression :: proc(expr: Maybe(Expression)) -> Term {
    result := Term(0)

    // If there is no expression, just return 0
    expression, ok := expr.?
    if !ok {
        return result
    }

    switch expr in expression {
        case Term:
            result = expr
        case SubExpression:
            result = evaluate_subexpression(expr)
    }

    return result
}

evaluate_subexpression :: proc(expr: SubExpression) -> Term {
    expr_lhs, lhs_ok := expr.lhs.?
    if !lhs_ok {
        expr_lhs = Term(0)
    }
    lhs := Term(0)
    switch l in expr_lhs {
    case Term:
        lhs = l
    case ^SubExpression:
        lhs = evaluate_subexpression(l^)
    }

    expr_rhs, rhs_ok := expr.rhs.?
    if !rhs_ok {
        expr_rhs = Term(0)
    }
    rhs := Term(0)
    switch r in expr_rhs {
    case Term:
        rhs = r
    case ^SubExpression:
        rhs = evaluate_subexpression(r^)
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
    switch &e in c.expr {
        case Term:
            // Promote the term into a sub expression
            existing_term := e
            c.expr = SubExpression{existing_term, nil, op}
        case SubExpression:
            // Otherwise overwrite the existing expression
            e.op = op
    }
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

