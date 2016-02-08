get_macro_symbol:
	push	ecx
	call	find_macro_symbol_leaf
	jc	macro_symbol_not_found
	mov	edx,[ebx]
	mov	ebx,esi
      try_macro_symbol:
	or	edx,edx
	jz	macro_symbol_not_found
	mov	ecx,[esp]
	mov	edi,[edx+4]
	repe	cmps byte [esi],[edi]
	je	macro_symbol_found
	mov	esi,ebx
	mov	edx,[edx]
	jmp	try_macro_symbol
      macro_symbol_found:
	pop	ecx
	clc
	ret
      macro_symbol_not_found:
	pop	ecx
	stc
	ret
      find_macro_symbol_leaf:
	shl	eax,8
	mov	al,cl
	mov	ebp,eax
	mov	ebx,macro_symbols
      follow_macro_symbols_tree:
	mov	edx,[ebx]
	or	edx,edx
	jz	no_such_macro_symbol
	xor	eax,eax
	shr	ebp,1
	adc	eax,0
	lea	ebx,[edx+eax*4]
	or	ebp,ebp
	jnz	follow_macro_symbols_tree
	add	ebx,8
	clc
	ret
      no_such_macro_symbol:
	stc
	ret
