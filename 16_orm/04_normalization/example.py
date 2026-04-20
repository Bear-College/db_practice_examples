"""
Нормалізація та денормалізація — normalized 3NF-style model vs one wide denormalized table.

Run: python example.py

Normalized: Customer, Order, OrderLine (no repeated customer data on every line).
Denormalized: one table repeating customer name/phone on each row (update anomalies).
"""
from __future__ import annotations

from decimal import Decimal

from sqlalchemy import ForeignKey, Numeric, String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session


class NormBase(DeclarativeBase):
    """Normalized schema — third normal form style."""

    pass


class Customer(NormBase):
    __tablename__ = "norm_customers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(40))
    orders: Mapped[list["NormOrder"]] = relationship(back_populates="customer")


class NormOrder(NormBase):
    __tablename__ = "norm_orders"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("norm_customers.id"))
    ref: Mapped[str] = mapped_column(String(40))
    customer: Mapped[Customer] = relationship(back_populates="orders")
    lines: Mapped[list["NormOrderLine"]] = relationship(back_populates="order", cascade="all, delete-orphan")


class NormOrderLine(NormBase):
    __tablename__ = "norm_order_lines"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("norm_orders.id"))
    sku: Mapped[str] = mapped_column(String(40))
    qty: Mapped[int] = mapped_column()
    unit_price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    order: Mapped[NormOrder] = relationship(back_populates="lines")


class DenormBase(DeclarativeBase):
    """Denormalized — one row per line with customer columns duplicated."""

    pass


class OrderLineFlat(DenormBase):
    __tablename__ = "denorm_order_lines_flat"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    order_ref: Mapped[str] = mapped_column(String(40))
    customer_name: Mapped[str] = mapped_column(String(120))
    customer_phone: Mapped[str] = mapped_column(String(40))
    sku: Mapped[str] = mapped_column(String(40))
    qty: Mapped[int] = mapped_column()
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)


def main() -> None:
    engine = create_engine("sqlite:///04_normalization_lab.db", echo=False)
    NormBase.metadata.drop_all(engine)
    DenormBase.metadata.drop_all(engine)
    NormBase.metadata.create_all(engine)
    DenormBase.metadata.create_all(engine)

    with Session(engine) as session:
        c = Customer(name="Olena", phone="+380-00")
        o = NormOrder(ref="SO-1", customer=c)
        o.lines.append(NormOrderLine(sku="TIRE-R17", qty=4, unit_price=Decimal("120.00")))
        session.add(o)
        session.add(
            OrderLineFlat(
                order_ref="SO-99",
                customer_name="Olena",
                customer_phone="+380-00",
                sku="WIPER",
                qty=2,
            )
        )
        session.commit()

    print("Normalized tables:", [t.name for t in NormBase.metadata.sorted_tables])
    print("Denormalized flat:", [t.name for t in DenormBase.metadata.sorted_tables])


if __name__ == "__main__":
    main()
