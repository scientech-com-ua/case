postpone_directive:
	push	esi
	mov	esi,edx
	xor	ecx,ecx
	call	add_preprocessor_symbol
	mov	eax,[current_line]
	mov	[error_line],eax
	mov	[edx+12],eax
	pop	esi
	mov	[edx+8],esi
	mov	al,[macro_status]
	and	al,0F0h
	or	al,1
	mov	[macro_status],al
	lods	byte [esi]
	or	al,al
	jz	line_preprocessed
	cmp	al,'{'
	jne	unexpected_characters
	jmp	found_macro_block
