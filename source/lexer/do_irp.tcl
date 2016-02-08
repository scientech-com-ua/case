do_irp:
	cmp	byte [esi],1Ah
	jne	invalid_macro_arguments
	movzx	eax,byte [esi+1]
	lea	esi,[esi+2+eax]
	lods	byte [esi]
	cmp	[base_code],1
	ja	irps_name_ok
	cmp	al,':'
	je	irp_with_default_value
	cmp	al,'='
	je	irp_with_default_value
	cmp	al,'*'
	jne	irp_name_ok
	lods	byte [esi]
      irp_name_ok:
	cmp	al,','
	jne	invalid_macro_arguments
	jmp	irp_parameters_start
      irp_with_default_value:
	xor	ebp,ebp
	or	[skip_default_argument_value],-1
	call	skip_macro_argument_value
	cmp	byte [esi],','
	jne	invalid_macro_arguments
	inc	esi
	jmp	irp_parameters_start
      irps_name_ok:
	cmp	al,','
	jne	invalid_macro_arguments
	cmp	[base_code],3
	je	irp_parameters_start
	mov	al,[esi]
	or	al,al
	jz	instant_macro_done
	cmp	al,'{'
	je	instant_macro_done
      irp_parameters_start:
	xor	eax,eax
	push	[free_additional_memory]
	push	[macro_symbols]
	mov	[macro_symbols],eax
	push	[counter_limit]
	mov	[counter_limit],eax
	mov	[struc_name],eax
	cmp	[base_code],3
	je	get_irpv_parameter
	mov	ebx,esi
	cmp	[base_code],2
	je	get_irps_parameter
	mov	edx,[parameters_end]
	mov	al,[edx]
	push	eax
	mov	byte [edx],0
      get_irp_parameter:
	inc	[counter_limit]
	mov	esi,[instant_macro_start]
	inc	esi
	call	get_macro_argument
	cmp	byte [ebx],','
	jne	irp_parameters_end
	inc	ebx
	jmp	get_irp_parameter
      irp_parameters_end:
	mov	esi,ebx
	pop	eax
	mov	[esi],al
	jmp	instant_macro_parameters_ok
      get_irps_parameter:
	mov	esi,[instant_macro_start]
	inc	esi
	lods	byte [esi]
	movzx	ecx,al
	inc	[counter_limit]
	mov	eax,[counter_limit]
	call	add_macro_symbol
	mov	[edx+12],ebx
	cmp	byte [ebx],1Ah
	je	irps_symbol
	cmp	byte [ebx],22h
	je	irps_quoted_string
	mov	eax,1
	jmp	irps_parameter_ok
      irps_quoted_string:
	mov	eax,[ebx+1]
	add	eax,1+4
	jmp	irps_parameter_ok
      irps_symbol:
	movzx	eax,byte [ebx+1]
	add	eax,1+1
      irps_parameter_ok:
	mov	[edx+8],eax
	add	ebx,eax
	cmp	byte [ebx],0
	je	irps_parameters_end
	cmp	byte [ebx],'{'
	jne	get_irps_parameter
      irps_parameters_end:
	mov	esi,ebx
	jmp	instant_macro_parameters_ok
      get_irpv_parameter:
	lods	byte [esi]
	cmp	al,1Ah
	jne	invalid_macro_arguments
	lods	byte [esi]
	mov	ebp,esi
	mov	cl,al
	mov	ch,10b
	call	get_preprocessor_symbol
	jc	instant_macro_finish
	push	edx
      mark_variable_value:
	inc	[counter_limit]
	mov	[edx+4],ebp
      next_variable_value:
	mov	edx,[edx]
	or	edx,edx
	jz	variable_values_marked
	mov	eax,[edx+4]
	cmp	eax,1
	jbe	next_variable_value
	mov	esi,ebp
	movzx	ecx,byte [esi-1]
	xchg	edi,eax
	repe	cmps byte [esi],[edi]
	xchg	edi,eax
	je	mark_variable_value
	jmp	next_variable_value
      variable_values_marked:
	pop	edx
	push	[counter_limit]
      add_irpv_value:
	push	edx
	mov	esi,[instant_macro_start]
	inc	esi
	lods	byte [esi]
	movzx	ecx,al
	mov	eax,[esp+4]
	call	add_macro_symbol
	mov	ebx,edx
	pop	edx
	mov	ecx,[edx+12]
	mov	eax,[edx+8]
	mov	[ebx+12],eax
	mov	[ebx+8],ecx
      collect_next_variable_value:
	mov	edx,[edx]
	or	edx,edx
	jz	variable_values_collected
	cmp	ebp,[edx+4]
	jne	collect_next_variable_value
	dec	dword [esp]
	jnz	add_irpv_value
      variable_values_collected:
	pop	eax
	mov	esi,ebp
	movzx	ecx,byte [esi-1]
	add	esi,ecx
	cmp	byte [esi],0
	je	instant_macro_parameters_ok
	cmp	byte [esi],'{'
	jne	invalid_macro_arguments
	jmp	instant_macro_parameters_ok
