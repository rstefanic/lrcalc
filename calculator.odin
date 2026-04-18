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

