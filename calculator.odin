package main

Operation :: enum {
    NONE,
    ADDITION,
    SUBTRACTION,
    MULTIPLICATION,
    DIVISION,
    MODULO,
}

Calculator :: struct {
    result: i64, // the result of all operations
    buffer: i64, // current value the user is entering in
    op: Operation,
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

