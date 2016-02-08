common_block:
	call	close_macro_block
	jc	process_macro_line
	mov	[counter],0
	jmp	new_macro_block
