forward_block:
	cmp	[counter_limit],0
	je	common_block
	call	close_macro_block
	jc	process_macro_line
	mov	[counter],1
	jmp	new_macro_block
