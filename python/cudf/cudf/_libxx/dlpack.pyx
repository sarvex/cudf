# Copyright (c) 2018, NVIDIA CORPORATION.

# cython: profile=False
# distutils: language = c++
# cython: embedsignature = True
# cython: language_level = 3

# Copyright (c) 2018, NVIDIA CORPORATION.
import cudf
from cudf._libxx.table cimport *
from cudf._libxx.table cimport *
from cudf._libxx.lib cimport *
import rmm


from libc.stdint cimport uintptr_t, int8_t
from libc.stdlib cimport calloc, malloc, free
from cpython cimport pycapsule

import numpy as np
import pandas as pd
import pyarrow as pa
import warnings

from cudf._libxx.includes.dlpack cimport (
    from_dlpack as cpp_from_dlpack,
    to_dlpack as cpp_to_dlpack,
    DLManagedTensor
)


def from_dlpack(dlpack_capsule):
    """
    Converts a DLPack Tensor PyCapsule into a list of cudf Column objects.

    DLPack Tensor PyCapsule is expected to have the name "dltensor".
    """
    warnings.warn("WARNING: cuDF from_dlpack() assumes column-major (Fortran"
                  " order) input. If the input tensor is row-major, transpose"
                  " it before passing it to this function.")

    cdef DLManagedTensor* dlpack_tensor = <DLManagedTensor*>pycapsule.\
        PyCapsule_GetPointer(dlpack_capsule, 'dltensor')
    pycapsule.PyCapsule_SetName(dlpack_capsule, 'used_dltensor')

    cdef unique_ptr[table] c_result

    with nogil:
        c_result = move(cpp_from_dlpack(
            dlpack_tensor
        ))

    return Table.from_unique_ptr(
        move(c_result),
        column_names=range(0, c_result.get()[0].num_columns())
    )


def to_dlpack(Table source_table):
    """
    Converts a a list of cudf Column objects into a DLPack Tensor PyCapsule.

    DLPack Tensor PyCapsule will have the name "dltensor".
    """

    warnings.warn("WARNING: cuDF to_dlpack() produces column-major (Fortran "
                  "order) output. If the output tensor needs to be row major, "
                  "transpose the output of this function.")

    cdef DLManagedTensor *dlpack_tensor
    cdef table_view source_table_view = source_table.data_view()

    with nogil:
        dlpack_tensor = cpp_to_dlpack(
            source_table_view
        )

    return pycapsule.PyCapsule_New(
        dlpack_tensor,
        'dltensor',
        dlmanaged_tensor_pycapsule_deleter
    )


cdef void dlmanaged_tensor_pycapsule_deleter(object pycap_obj):
    cdef DLManagedTensor* dlpack_tensor= <DLManagedTensor*>0
    try:
        dlpack_tensor = <DLManagedTensor*>pycapsule.PyCapsule_GetPointer(
            pycap_obj, 'used_dltensor')
        return  # we do not call a used capsule's deleter
    except Exception:
        dlpack_tensor = <DLManagedTensor*>pycapsule.PyCapsule_GetPointer(
            pycap_obj, 'dltensor')
    dlpack_tensor.deleter(dlpack_tensor)
