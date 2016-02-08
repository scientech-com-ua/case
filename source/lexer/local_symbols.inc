local_symbols:
	lods	byte [esi]
	cmp	al,1Ah
	jne	invalid_argument
	mov	byte [edi-1],3Bh
	xor	al,al
	stos	byte [edi]
      make_local_symbol:
	push	ecx
	lods	byte [esi]
	movzx	ecx,al
	mov	eax,[counter]
	call	add_macro_symbol
	mov	[edx+12],edi
	movzx	eax,[locals_counter]
	add	eax,ecx
	inc	eax
	cmp	eax,100h
	jae	name_too_long
	lea	ebp,[edi+2+eax]
	cmp	ebp,[memory_end]
	jae	out_of_memory
	mov	ah,al
	mov	al,1Ah
	stos	word [edi]
	rep	movs byte [edi],[esi]
	mov	al,'?'
	stos	byte [edi]
	push	esi
	mov	esi,locals_counter+1
	movzx	ecx,[locals_counter]
	rep	movs byte [edi],[esi]
	pop	esi
	mov	eax,edi
	sub	eax,[edx+12]
	mov	[edx+8],eax
	xor	al,al
	stos	byte [edi]
	mov	eax,locals_counter
	movzx	ecx,byte [eax]
      counter_loop:
	inc	byte [eax+ecx]
	cmp	byte [eax+ecx],'9'+1
	jb	counter_ok
	jne	letter_digit
	mov	byte [eax+ecx],'A'
	jmp	counter_ok
      letter_digit:
	cmp	byte [eax+ecx],'Z'+1
	jb	counter_ok
	jne	small_letter_digit
	mov	byte [eax+ecx],'a'
	jmp	counter_ok
      small_letter_digit:
	cmp	byte [eax+ecx],'z'+1
	jb	counter_ok
	mov	byte [eax+ecx],'0'
	loop	counter_loop
	inc	byte [eax]
	movzx	ecx,byte [eax]
	mov	byte [eax+ecx],'0'
      counter_ok:
	pop	ecx
	lods	byte [esi]
	cmp	al,'}'
	je	macro_block_processed
	or	al,al
	jz	process_next_line
	cmp	al,','
	jne	extra_characters_on_line
	dec	edi
	lods	byte [esi]
	cmp	al,1Ah
	je	make_local_symbol
	jmp	invalid_argument
