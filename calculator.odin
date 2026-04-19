package main

import "core:fmt"
import "core:mem"
import "core:strings"

Operator :: enum {
    ADDITION,
    SUBTRACTION,
    MULTIPLICATION,
    DIVISION,
    MODULO,
}

Term :: distinct i64

SubExpression :: struct {
    lhs: Expression,
    rhs: Maybe(Expression),
    op: Operator
}

Expression :: union {
    ^SubExpression,
    Term
}

Calculator :: struct {
    arena: mem.Arena,
    allocator: mem.Allocator,
    buffer: i64, // current value the user is entering in
    expr: Expression,
}

init_calculator :: proc(c: ^Calculator) {
    arena_buffer := make([]byte, mem.Kilobyte)
    mem.arena_init(&c.arena, arena_buffer)
    c.allocator = mem.arena_allocator(&c.arena)
    reset(c)
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
    new_expr := new(SubExpression, c.allocator)

    switch &e in c.expr {
        case Term:
            new_expr.lhs = buf
        case ^SubExpression:
            e.rhs = buf
            new_expr.lhs = e
    }

    new_expr.rhs = nil
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
    // Move the buffer from the term into the rhs
    #partial switch e in c.expr {
    case ^SubExpression:
        last_term := Term(c.buffer)
        e.rhs = last_term
        c^.expr = evaluate_expression(e) // evaluate into a single term
    }
    c^.buffer = 0   // reset the buffer
}

reset :: proc(c: ^Calculator) {
    mem.arena_free_all(&c.arena)
    c^.expr = Term(0)
    c^.buffer = 0   // reset the buffer
}

format_expression :: proc(sb: ^strings.Builder, expression: Expression) {
    switch e in expression {
    case Term:
        fmt.sbprintf(sb, "%d", e)
    case ^SubExpression:
        // lhs
        format_expression(sb, e.lhs)

        // operator
        switch e.op {
        case .ADDITION:
            fmt.sbprintf(sb, " + ")
        case .SUBTRACTION:
            fmt.sbprintf(sb, " - ")
        case .MULTIPLICATION:
            fmt.sbprintf(sb, " * ")
        case .DIVISION:
            fmt.sbprintf(sb, " / ")
        case .MODULO:
            fmt.sbprintf(sb, " % ")
        }

        rhs, ok := e.rhs.?
        if ok {
            fmt.sbprintf(sb, "%d", rhs)
        } else {
            fmt.sbprintf(sb, " ")
        }
    }
}
