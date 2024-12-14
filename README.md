# sunflowersproject

# Top-Down Circuit Bounds Formalization

This repository contains a first step towards the Coq formalization of the paper "Top-Down Lower Bounds for Depth-Three Circuits" by Håstad, Jukna & Pudlák (1995). 

## Overview

The code formalizes several key concepts from circuit complexity theory:

- AC0 circuits with bounded depth
- k-limits and sunflowers used in lower bound proofs
- The Erdős-Rado sunflower theorem (incomplete - made significant process towards completing it, December 2024)
- Boolean function evaluation and circuit separation properties

## Main Theorems

The formalization works toward proving several key results:

1. **Circuit Separation (Lemma 2.2)**: Shows relationship between k-limits and circuit separation
2. **Sunflower Theorem**: Erdős-Rado sunflower theorem for set systems
3. **Parity Lower Bound**: Exponential lower bound for computing parity
4. **Fan-in Reduction**: Deterministic technique for reducing bottom fan-in of circuits

## Structure

- Basic definitions and circuit types
- Set theory operations and properties
- k-limit and sunflower definitions and lemmas
- Main theorems and their supporting lemmas
- Arithmetic bounds and helper functions

## Current Status

Some key lemmas are currently admitted, particularly:
- Complex combinatorial arguments in sunflower theorem
- Some arithmetic bounds and inequalities
- Parts of the main circuit separation theorem

Work is ongoing to complete these proofs.

## Dependencies

The formalization relies on several Coq standard libraries:
- `Coq.Bool.Bool`
- `Coq.Lists.List`
- `Coq.Arith.PeanoNat`
- `Coq.Numbers.Natural.Peano.NPeano`
- `Coq.Reals.Reals`
- `Coq.ZArith.ZArith`

## Usage

To work with this formalization:

1. Ensure you have Coq installed (tested with Coq 8.13+)
2. Load the file in your preferred Coq IDE (e.g., CoqIDE or ProofGeneral)
3. Step through the proofs and definitions

## Contributing

Areas where contributions would be particularly valuable:
- Completing admitted proofs
- Adding automation tactics for arithmetic bounds
- Improving proof structure and documentation
- Adding examples and test cases

## References

Håstad, J., Jukna, S., & Pudlák, P. (1995). Top-Down Lower Bounds for Depth-Three Circuits. computational complexity, 5, 99-112.
