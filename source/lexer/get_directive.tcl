get_directive:
	push	edi
	mov	edx,esi
	mov	ebp,ecx
	call	lower_case
	pop	edi
      scan_directives:
	mov	esi,converted
	movzx	eax,byte [edi]
	or	al,al
	jz	no_directive
	mov	ecx,ebp
	inc	edi
	mov	ebx,edi
	add	ebx,eax
	mov	ah,[esi]
	cmp	ah,[edi]
	jb	no_directive
	ja	next_directive
	cmp	cl,al
	jne	next_directive
	repe	cmps byte [esi],[edi]
	jb	no_directive
	je	directive_ok
      next_directive:
	mov	edi,ebx
	add	edi,2
	jmp	scan_directives
      no_directive:
	mov	esi,edx
	mov	ecx,ebp
	stc
	ret
      directive_ok:
	lea	esi,[edx+ebp]
	call	directive_handler
      directive_handler:
	pop	ecx
	movzx	eax,word [ebx]
	add	eax,ecx
	clc
	ret
