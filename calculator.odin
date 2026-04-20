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
Variable :: struct {
    name: string,
    ref: ^Calculator
}

SubExpression :: struct {
    lhs: Expression,
    rhs: Maybe(Expression),
    op: Operator
}

Expression :: union {
    ^SubExpression,
    Term,
    Variable
}

Calculator :: struct {
    arena: mem.Arena,
    allocator: mem.Allocator,
    buffer: union {
        i64,
        Variable,
    }, // current value the user is entering in
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
        case Variable:
            result = evaluate_expression(expression.ref.expr)
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
    case Variable:
        lhs = evaluate_expression(l.ref.expr)
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
    case Variable:
        rhs = evaluate_expression(r.ref.expr)
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
    expr: Expression
    switch buf in c.buffer {
    case i64:
        expr = Term(buf)
    case Variable:
        expr = buf
    }

    new_expr := new(SubExpression, c.allocator)
    #partial switch &e in c.expr {
        case Term:
            new_expr.lhs = expr
        case ^SubExpression:
            e.rhs = expr
            new_expr.lhs = e
    }

    new_expr.rhs = nil
    new_expr.op = op
    c.expr = new_expr
    c^.buffer = 0       // reset the buffer
}

equals :: proc(c: ^Calculator) {
    // Move the buffer from the term into the rhs
    #partial switch e in c.expr {
    case ^SubExpression:
        expr: Expression
        switch buf in c.buffer {
        case i64:
            expr = Term(buf)
        case Variable:
            expr = buf
        }
        e.rhs = expr
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
    case Variable:
        fmt.sbprintf(sb, "%s", e.name)
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

add_digit_to_buffer :: proc(c: ^Calculator, n: i64) {
    #partial switch &buf in c.buffer {
    case i64:
        buf = (buf * 10) + n
    }
}

pop_last_digit :: proc(c: ^Calculator) {
    #partial switch &buf in c.buffer {
    case i64:
        buf /= 10
    }
}

flip_sign :: proc(c: ^Calculator) {
    #partial switch &buf in c.buffer {
    case i64:
        buf *= -1
    }
}
