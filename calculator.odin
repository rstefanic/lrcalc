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
    // TODO: Remove these
    result: i64, // the result of all operator
    op: Operator,

    // TODO: KEEP
    buffer: i64, // current value the user is entering in
    expr: Maybe(Expression)
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
    expr, ok := c.expr.?

    // If the expression is empty, we'll promote the buffer
    // to the term first before setting the operator.
    if !ok {
        create_term_from_buffer(c)
        expr, ok = c.expr.?
        if !ok {
            panic("could not convert buffer to expression term")
        }
    }

    switch &e in expr {
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
    c^.expr = new_term          // copy the tery
    c^.buffer = 0               // reset the buffer
}

equals :: proc(c: ^Calculator) {
    switch c.op {
    case .NONE:
        // Do nothing if there is no operator set
        return 
    case .ADDITION:
        c^.result += c.buffer
    case .SUBTRACTION:
        c^.result -= c.buffer
    case .MULTIPLICATION:
        c^.result *= c.buffer
    case .DIVISION:
        // TODO: Handle case where we may try to divide by 0
        c^.result /= c.buffer
    case .MODULO:
        c^.result = c.result % c.buffer
    }

    c^.buffer = 0
    c^.op = .NONE
}

