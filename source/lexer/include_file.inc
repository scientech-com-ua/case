include_file:
	lods	byte [esi]
	cmp	al,22h
	jne	invalid_argument
	lods	dword [esi]
	cmp	byte [esi+eax],0
	jne	extra_characters_on_line
	push	esi
	push	edi
	mov	ebx,[current_line]
      find_current_file_path:
	mov	esi,[ebx]
	test	byte [ebx+7],80h
	jz	copy_current_file_path
	mov	ebx,[ebx+8]
	jmp	find_current_file_path
      copy_current_file_path:
	lods	byte [esi]
	stos	byte [edi]
	or	al,al
	jnz	copy_current_file_path
      cut_current_file_name:
	cmp	edi,[esp]
	je	current_file_path_ok
	cmp	byte [edi-1],'\'
	je	current_file_path_ok
	cmp	byte [edi-1],'/'
	je	current_file_path_ok
	dec	edi
	jmp	cut_current_file_name
      current_file_path_ok:
	mov	esi,[esp+4]
	call	expand_path
	pop	edx
	mov	esi,edx
	call	open
	jnc	include_path_ok
	mov	ebp,[include_paths]
      try_include_directories:
	mov	edi,esi
	mov	esi,ebp
	cmp	byte [esi],0
	je	try_in_current_directory
	push	ebp
	push	edi
	call	get_include_directory
	mov	[esp+4],esi
	mov	esi,[esp+8]
	call	expand_path
	pop	edx
	mov	esi,edx
	call	open
	pop	ebp
	jnc	include_path_ok
	jmp	try_include_directories
	mov	edi,esi
      try_in_current_directory:
	mov	esi,[esp]
	push	edi
	call	expand_path
	pop	edx
	mov	esi,edx
	call	open
	jc	file_not_found
      include_path_ok:
	mov	edi,[esp]
      copy_preprocessed_path:
	lods	byte [esi]
	stos	byte [edi]
	or	al,al
	jnz	copy_preprocessed_path
	pop	esi
	lea	ecx,[edi-1]
	sub	ecx,esi
	mov	[esi-4],ecx
	push	dword [macro_status]
	and	[macro_status],0Fh
	call	preprocess_file
	pop	eax
	and	al,0F0h
	and	[macro_status],0Fh
	or	[macro_status],al
	jmp	line_preprocessed
