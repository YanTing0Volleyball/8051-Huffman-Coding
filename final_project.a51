; Huffman Coding for 8051
; Internal RAM Planning:
; 30H-4FH: For Frequency Table (A-Z Frequency)
; 07H: For Stack Pointer Start (inital stack pointer)
; 70H: For Template Space 
; 50H: For Node Pool Count
; 51H, 53H: For Position Recorder
; 52H: For Position Counter
;
; External Ram Planning:
; 0100H ~ 01FFH: For Node Pool
; 0300H ~ 03FFH: For Node List
; 0400H ~ 04FFH: For Huffman Table
; 0500H ~ 05FFH: For Result Output
;
; Structure Define
; Node: Frequenc, ASCII, Left Node Address, Right Node Address
; ASCII: 00 => No ASCII, Left Node: FF => No Left Node, Right Node: FF => No Right Node


NODEPOOL_START EQU 0100H
NODE_LIST_START EQU 0300H
HUFFMAN_TABLE_START EQU 0400H

; Input String Setting
ORG 0300H
INPUT_STRING:
    DB 'ABCCAAA', 0  ; Zero trailed

ORG 0000H
MAIN:
    ; Clear Frequency Table
    MOV R0, #30H
    MOV R1, #26     ; 26 Number of Character
CLEAR_FREQ:
    MOV @R0, #00H
    INC R0
    DJNZ R1, CLEAR_FREQ
    
    ; Calculate frequency table
    MOV DPTR, #INPUT_STRING    ; Set input string pointer
COUNT_FREQ:
	MOV A, #0
    MOVC A, @A + DPTR
    JZ FREQ_DONE    ; Frequency Calculate Finished
    
    ; Increase Frequency
	CLR C
    SUBB A, #'A'    ; Substract ASCII value of 'A'
    ADD A, #30H     ; Add start address #30h to find address refer to character
    MOV R1, A
    INC @R1         ; Add one the the frequency
    
    INC DPTR
    SJMP COUNT_FREQ
    
FREQ_DONE:
	; Template Buile Up Node
	MOV DPTR, #NODEPOOL_START
	MOV R0, #30H   ; Point to frequency table
	MOV R7, #0     ; R7 Record Number of Node in List
	MOV 50H, #0    ; Initial Node Pool Count
	MOV P2, #03H  ; Point to node list
	MOV R1, #00H  ; Point to node list
	MOV R3, #26   
	
	
INITIAL_BUILD_NEXT_NODE:
	MOV A, @R0
	JZ SKIP_NODE ; Skip if frequency equal to zero
	
	INC R7     ; Increment Node List Count
	INC 50H    ; Increment Node Pool Count
	MOV A, DPL
	MOVX @R1, A
	INC R1
	MOV A, @R0
	MOVX @DPTR, A
	INC DPTR
	MOV A, R0
	SUBB A, #30H
	ADD A, #'A'
	MOVX @DPTR, A
	INC DPTR
	MOV A, #0FFH
	MOVX @DPTR, A  ; Initial Null Child Node
	INC DPTR
	MOVX @DPTR, A
	INC DPTR
	
SKIP_NODE:
	INC R0
	DJNZ R3, INITIAL_BUILD_NEXT_NODE


; Build Huffman Tree
BUILD_TREE:
    ; Check if only one node remains (tree is complete)
    MOV A, R7
    CJNE A, #1, CONTINUE_BUILD
    LJMP BUILD_COMPLETE
    
CONTINUE_BUILD:
    MOV DPH, #01H   ; Point to node pool
	; Find two minimum frequency nodes
    MOV R2, #0FFH   ; Initialize min 1 frequency to max
    MOV R3, #0      ; min1 node address
	MOV 51H, #0     ; Store Min 1 Position in Node List
    
    MOV R0, #00H    ; Point to node list
	MOV P2, #03H    ; Point to node list
	MOV A, R7
    MOV R1, A      ; Number of nodes to check
	MOV 52H, #0     ; Initial Current position counter
    
FIND_MIN1:
	MOVX A, @R0
	MOV DPL, A
	
    MOVX A, @DPTR   ; Get frequency
	MOV R4, A
	CLR C
	SUBB A, R2
    JNC NEXT_NODE1
    
	MOV A, R4
    MOV R2, A       ; Update min1 frequency
    MOV R3, DPL     ; Store min1 node address
	MOV 51H, 52H    ; Store position
    
NEXT_NODE1:
	INC 52H
	INC R0
    DJNZ R1, FIND_MIN1

    ; Find second minimum (similar process)
    MOV R5, #0FFH   ; Initialize min 2 frequency
    MOV R6, #0      ; min2 node address
	MOV 53H, #0     ; Store min2 position in node list
    
    MOV R0, #00H    ; Point to node list
	MOV P2, #03H    ; Point to node list
	MOV A, R7
    MOV R1, A
	MOV 52H, #0
    
FIND_MIN2:
    MOVX A, @R0
    
    ; Skip if this is min1 node
	MOV R4, A
	CLR C
	SUBB A, R3
    JZ NEXT_NODE2
    
	MOV A, R4
	MOV DPL, A
    MOVX A, @DPTR
	
	MOV R4, A
	CLR C
	SUBB A, R5
    JC UPDATE_MIN2
    SJMP NEXT_NODE2
    
UPDATE_MIN2:
	MOV A, R4
    MOV R5, A
    MOV R6, DPL
	MOV 53H, 52H   ; Store Position
    
NEXT_NODE2:
	INC R0
	INC 52H
    DJNZ R1, FIND_MIN2
    
    ; Create new parent node
    MOV DPH, #01H   ; NODEPOOL_START
    MOV A, 50H      ; Get Current Node Pool Count
	MOV B, #04H     ; Each Node Takes 4 byte
	MUL AB          ; A = 50H * 4
	MOV DPL, A      ; Set to next available node
	
	INC 50H
    
    ; Store frequency sum
    MOV A, R2
    ADD A, R5
    MOVX @DPTR, A
    INC DPTR
    
    ; Store ASCII (0 for internal node)
    MOV A, #0
    MOVX @DPTR, A
    INC DPTR
    
    ; Store left child
    MOV A, R3
    MOVX @DPTR, A
    INC DPTR
    
    ; Store right child
    MOV A, R6
    MOVX @DPTR, A
    INC DPTR
    
	
    ; Update Node List - Remove the two min nodes and add the new parent
    ; First, shift all nodes after min2 position left by 2 bytes
    MOV P2, #03H    ; Point to node list
	MOV R0, #00H    ; Point to node list
    MOV A, 53H      ; Get min2 position
    ADD A, R0       ; R0 points to min2 position
    MOV R0, A
    
    MOV A, R7       ; Total nodes
    CLR C
    SUBB A, 53H     ; Remaining nodes after min2
    MOV R4, A       ; Counter for shifting

SHIFT_AFTER_MIN2:
	MOV A, R0
	ADD A, #1
	MOV R1, A
	
	MOVX A, @R1
	MOV R3, A
	MOV A, #00H
	MOVX @R1, A
	MOV A, R3
	MOVX @R0, A
	
	INC R0
	DJNZ R4, SHIFT_AFTER_MIN2
	
    
    ; Now shift all nodes after min1 position left by 2 bytes
SHIFT_MIN1:
    MOV P2, #03H
	MOV R0, #00H
    MOV A, 51H      ; Get min1 position
    ADD A, R0       ; R0 points to min1 position
    MOV R0, A
    
    MOV A, R7       ; Total nodes
    CLR C
    SUBB A, 51H     ; Remaining nodes after min1
    MOV R4, A       ; Counter for shifting
	
SHIFT_AFTER_MIN1:
    MOV A, R0
	ADD A, #1
	MOV R1, A
	
	MOVX A, @R1
	MOV R3, A
	MOV A, #00H
	MOVX @R1, A
	MOV A, R3
	MOVX @R0, A
		
	INC R0
	DJNZ R4, SHIFT_AFTER_MIN1
    
    ; Add new parent node to end of list
ADD_NEW_NODE:
	MOV P2, #03H    ; Point to node list
    MOV R0, #00H    ; Point to node list
    MOV A, R7
    DEC A
	DEC A           ; Two nodes removed
    MOV R0, A
   
    MOV A, DPL      ; Store new parent node address
	DEC A
	DEC A
	DEC A
	DEC A
    MOVX @R0, A
    
    ; Update node count
    DEC R7          ; Remove two nodes and add one new node
    
    LJMP BUILD_TREE
    
	
	
BUILD_COMPLETE:
    ; Initialize Huffman table generation
    MOV DPTR, #HUFFMAN_TABLE_START  
    
    ; Clear Huffman table first
    MOV R3, #52    ; 26 characters * 2 bytes
    MOV P2, #04H   ; Point to Huffman table
    MOV R0, #00H
CLEAR_TABLE:
    MOV A, #0
    MOVX @R0, A
    INC R0
    DJNZ R3, CLEAR_TABLE
    
    ; Initialize for code generation
    MOV R2, #00H                    ; Current bit position in code
    MOV 70H, #0                     ; Clear temporary storage
    
    ; Get root node address from node list
    MOV P2, #03H
    MOV R0, #00H
    MOVX A, @R0                     ; Get root node address
    MOV R7, A                       ; Store root address in R7
    
    ; Start recursive traversal
    LCALL GENERATE_CODES
    LJMP ENCODE

; Recursive function to generate Huffman codes
; R7: Current node address
; R2: Current bit position in code
; 70H: Temporary storage for code
GENERATE_CODES:
    PUSH 2        ; Save current state
    PUSH 7
    PUSH DPH
    PUSH DPL	; Save bank select
    
    MOV DPH, #01H ; Point to node pool
    MOV DPL, R7
    
    ; Check if leaf node (has ASCII character)
    INC DPTR      ; Point to ASCII field
    MOVX A, @DPTR
    JZ NOT_LEAF   ; If ASCII is 0, not a leaf
    
    
    ; Set up destination address
    MOV P2, #04H  ; HUFFMAN_TABLE_START high byte
	CLR C
    ADD A, #-'A'  ; Convert ASCII to index (A-A = 0)
	CLR C
    RLC A          ; Multiply by 2 to get offset (2 bytes per entry)
    MOV R0, A     ; Use R0 for indirect addressing
    
    ; Store code length
    MOV A, R2
    MOVX @R0, A
    INC R0
    
    ; Store actual code
    MOV A, 70H
    MOVX @R0, A
    
    SJMP GENERATE_DONE
    
NOT_LEAF:
    ; Process left child
    INC DPTR      ; Point to left child address
    MOVX A, @DPTR
    CJNE A, #0FFH, HAS_LEFT  ; Check if left child exists
    SJMP CHECK_RIGHT
    
HAS_LEFT:
    ; Add 0 to current code
    MOV A, 70H
    CLR C         ; Clear carry (add 0)
    RLC A         ; Rotate left through carry
    MOV 70H, A
    INC R2        ; Increment bit count
    
    MOVX A, @DPTR
    MOV R7, A     ; Set new current node
    LCALL GENERATE_CODES
    
    ; Remove last bit
    MOV A, 70H
	CLR C
    RRC A
    MOV 70H, A
    DEC R2
    
CHECK_RIGHT:
    ; Process right child
    INC DPTR      ; Point to right child address
    MOVX A, @DPTR
    CJNE A, #0FFH, HAS_RIGHT
    SJMP GENERATE_DONE
    
HAS_RIGHT:
    ; Add 1 to current code
    MOV A, 70H
    SETB C        ; Set carry (add 1)
    RLC A         ; Rotate left through carry
    MOV 70H, A
    INC R2        ; Increment bit count
    
    MOVX A, @DPTR
    MOV R7, A     ; Set new current node
    LCALL GENERATE_CODES
    
    ; Remove last bit
    MOV A, 70H
    RRC A
    MOV 70H, A
    DEC R2
    
GENERATE_DONE:
    POP DPL
    POP DPH	; Restore state
    POP 7
    POP 2
    RET
	
	
ENCODE:
    ; Initial memory position
	MOV R0, #0         ; For huffman table pointer
    MOV R1, #1         ; For out put possition pointer
    MOV R2, #0         ; Encode length counter
	MOV R3, #0         ; Current word
	MOV R4, #0		   ; Current word length
	MOV R5, #0         ; Encode code
	MOV R6, #0         ; Encode length
    
    ; Input string pointer
    MOV DPTR, #INPUT_STRING
    
ENCODE_NEXT_CHAR:
    ; Read next character
    MOV A, #0
    MOVC A, @A+DPTR
    JZ ENCODE_DONE     ; 0 input string over
    
    ; Encode character    
	CLR C
    ADD A, #-'A'
    CLR C
    RLC A              ; Multiply 2 to get huffman table index
    
    ; Setting Huffman table pointer
    MOV P2, #04H
    MOV R0, A
    
    ; Load encode length
    MOVX A, @R0
    MOV R6, A          ; R6 save encode length
    INC R0
    
    ; Load huffmann encode code
    MOVX A, @R0
    MOV R5, A          ; R5 save encode code
    
    ; Encode Bist
ENCODE_BITS:
	; Prerotate first
	MOV A, #8
	SUBB A, R6
	MOV R7, A
	JZ START_EXTRACT
	
PREROTATE_LOOP:
	MOV A, R5
	CLR C
	RLC A
	MOV R5, A
	DJNZ R7, PREROTATE_LOOP

START_EXTRACT:
    ; Left rotate get bit from carry
    MOV A, R5
    RLC A              ; Carry
    MOV R5, A
    
    ; Add to current word
    MOV A, R3
    RLC A
    MOV R3, A
    
    ; Inc counter
    INC R2
	INC R4
    
    ; Check wether current word is 8 bit
    MOV A, R4
    ANL A, #07H        ; Check lest thrid bit
    JNZ CONTINUE_ENCODE
    
    ; Save Current word
    MOV P2, #05H
	MOV A, R3
    MOVX @R1, A
	MOV R3, #0
	MOV R4, #0
	INC R1
    
CONTINUE_ENCODE:
    DJNZ R6, START_EXTRACT
    
    ; Continue to next character
    INC DPTR
    SJMP ENCODE_NEXT_CHAR

ENCODE_DONE:
    ; Last word need store
    MOV A, R4
    ANL A, #07H
    JZ NO_PARTIAL_BYTE
    
ROTATE_BEFORE_PUSH:
    MOV A, R3
	RR A
	MOV R3, A
	DJNZ R4, ROTATE_BEFORE_PUSH
	
    MOV P2, #05H
	MOVX @R1, A
    
NO_PARTIAL_BYTE:
    ; Store total number of bit
	MOV R1, #00H
    MOV P2, #05H
	MOV A, R2
	MOVX @R1, A
    
    SJMP $ 
END
	






