counter := 0

f: func -> Range {
    counter += 1 // Side effects!

    10 .. 15
}

describe("foreach should iterate through any range expression, not just literals", ||

    for ((j, i) in f()) {
        expect(j, i + 10)
    }

    expect(counter, 1)
)
